{ edit16: EDIT.EXE, a full-screen text editor for 16-bit real-mode DOS
  with the menus, dialog boxes and keys of MS-DOS EDIT, built on Free
  Pascal's FreeVision.  See README.md and docs/COMPAT.md. }

program Edit16;

{$mode fpc}

uses
  Dos, Objects, Drivers, Views, Menus, Dialogs, App, MsgBox, Editors,
  FVConsts, EdSys, EdTest, EdView, EdDlg, EdHelp;

const
  MinStartHeap = 32768;   { bytes of heap needed to start }

{$I version.inc}

const
  MaxWindows = 9;
  MaxArgs    = 9;

  cmSplit    = 1200;
  cmFull     = 1201;
  cmDisplay  = 1202;
  cmStarted  = 1203;
  cmKeys     = 1204;
  cmAbout    = 1205;
  cmWin1     = 1211;   { .. cmWin1 + 8: the View menu's list of files }

type
  TEditApp = object (TApplication)
    constructor Init;
    destructor Done; virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure InitScreen; virtual;
    function  GetPalette : PPalette; virtual;
    procedure GetEvent (var Event : TEvent); virtual;
    procedure HandleEvent (var Event : TEvent); virtual;
    procedure Idle; virtual;
  private
    AltDown, AltUsed : Boolean;
    Split      : Boolean;
    InHelp     : Boolean;
    LastEditor : PEdEditor;
    LastPos    : TPoint;
    Untitled   : Integer;
    ViewItem   : PMenuItem;
    function  WindowCount : Integer;
    function  FreeNumber : Integer;
    function  FindFile (const Name : FNameStr) : PEdWindow;
    procedure AddWindow (W : PEdWindow);
    procedure NewFile;
    procedure OpenFile (Name : FNameStr);
    procedure OpenWithDialog (const Mask : FNameStr);
    procedure Arrange;
    procedure ApplyDisplay;
    procedure Print;
    procedure RebuildViewMenu;
    function  ViewMenu : PMenu;
  end;

var
  EditApp   : TEditApp;
  ColorPal  : String;
  ForceBW   : Boolean;
  Args      : array[1..MaxArgs] of FNameStr;
  ArgCount  : Integer;

{ -------------------------------------------------------------------- }

function WindowOf (P : PView) : PEdWindow;
begin
  if (P <> nil) and (TypeOf (P^) = TypeOf (TEdWindow)) then
    WindowOf := PEdWindow (P)
  else
    WindowOf := nil;
end;

function TEditApp.WindowCount : Integer;
var
  P : PView;
  N : Integer;
begin
  N := 0;
  P := Desktop^.Last;
  if P <> nil then
    repeat
      if WindowOf (P) <> nil then
        Inc (N);
      P := P^.Prev;
    until P = Desktop^.Last;
  WindowCount := N;
end;

function TEditApp.FreeNumber : Integer;
var
  N : Integer;
  P : PView;
  Used : Boolean;
begin
  for N := 1 to MaxWindows do
    begin
      Used := False;
      P := Desktop^.Last;
      if P <> nil then
        repeat
          if (WindowOf (P) <> nil) and (PEdWindow (P)^.Number = N) then
            Used := True;
          P := P^.Prev;
        until P = Desktop^.Last;
      if not Used then
        begin
          FreeNumber := N;
          Exit;
        end;
    end;
  FreeNumber := wnNoNumber;
end;

function IsDirectory (const Path : String) : Boolean;
var
  SR : SearchRec;
begin
  FindFirst (Path, Directory + ReadOnly + Hidden + SysFile + Archive, SR);
  IsDirectory := (DosError = 0) and (SR.Attr and Directory <> 0);
  FindClose (SR);
end;

function SameName (const A, B : String) : Boolean;
var
  I : Integer;
begin
  SameName := False;
  if Length (A) <> Length (B) then
    Exit;
  for I := 1 to Length (A) do
    if UpCase (A[I]) <> UpCase (B[I]) then
      Exit;
  SameName := True;
end;

function TEditApp.FindFile (const Name : FNameStr) : PEdWindow;
var
  P : PView;
begin
  FindFile := nil;
  P := Desktop^.Last;
  if P <> nil then
    repeat
      if (WindowOf (P) <> nil) and SameName (PEdWindow (P)^.Editor^.FileName, Name) then
        begin
          FindFile := PEdWindow (P);
          Exit;
        end;
      P := P^.Prev;
    until P = Desktop^.Last;
end;

procedure TEditApp.AddWindow (W : PEdWindow);
begin
  if ValidView (W) <> nil then
    begin
      Desktop^.Insert (W);
      if Split then
        Arrange;
    end;
end;

procedure TEditApp.NewFile;
var
  R : TRect;
begin
  if WindowCount >= MaxWindows then
    begin
      ErrorBox ('No more than 9 files can be open.');
      Exit;
    end;
  Inc (Untitled);
  Desktop^.GetExtent (R);
  AddWindow (New (PEdWindow, Init (R, '', FreeNumber, Untitled)));
end;

{ Opens Name in a new window, or brings forward the window that already
  has it.  A file that does not exist is a new one by that name. }
procedure TEditApp.OpenFile (Name : FNameStr);
var
  R  : TRect;
  W  : PEdWindow;
  SR : SearchRec;
  D  : DirStr;
  N  : NameStr;
  X  : ExtStr;
  Exists : Boolean;
begin
  Name := FExpand (Name);
  W := FindFile (Name);
  if W <> nil then
    begin
      W^.Select;
      Exit;
    end;
  if WindowCount >= MaxWindows then
    begin
      ErrorBox ('No more than 9 files can be open.');
      Exit;
    end;
  FSplit (Name, D, N, X);
  if N + X = '' then
    begin
      ErrorBox ('Bad file name.');
      Exit;
    end;
  FindFirst (Name, ReadOnly + Hidden + SysFile + Archive + Directory, SR);
  Exists := DosError = 0;
  FindClose (SR);
  if Exists and (SR.Attr and Directory <> 0) then
    begin
      ErrorBox (N + X + ' is a directory.');
      Exit;
    end;
  if Exists then
    begin
      if SR.Size > MaxFileSize then
        begin
          ErrorBox (N + X + ' is too large (over 65,280 bytes).');
          Exit;
        end;
      if MaxAvail < SR.Size + MinBufLength + MemReserve then
        begin
          ErrorBox ('Not enough memory to open ' + N + X + '.');
          Exit;
        end;
    end
  else if (Length (D) > 3) and not IsDirectory (Copy (D, 1, Length (D) - 1)) then
    begin
      ErrorBox ('Path not found: ' + D);
      Exit;
    end;
  Desktop^.GetExtent (R);
  if Exists then
    W := New (PEdWindow, Init (R, Name, FreeNumber, 0))
  else
    begin
      W := New (PEdWindow, Init (R, '', FreeNumber, 0));
      W^.Editor^.FileName := Name;
    end;
  AddWindow (W);
end;

procedure TEditApp.OpenWithDialog (const Mask : FNameStr);
var
  Name : FNameStr;
begin
  Name := Mask;
  if OpenDialog (Name) then
    begin
      if FSearch (Name, '') = '' then
        ErrorBox ('File not found.')
      else
        OpenFile (Name);
    end;
end;

{ Split: tile every window; otherwise each gets the whole desktop. }
procedure TEditApp.Arrange;
var
  R : TRect;
  P : PView;
begin
  Desktop^.GetExtent (R);
  if Split then
    Desktop^.Tile (R)
  else
    begin
      P := Desktop^.Last;
      if P <> nil then
        repeat
          if WindowOf (P) <> nil then
            P^.Locate (R);
          P := P^.Prev;
        until P = Desktop^.Last;
    end;
end;

procedure TEditApp.ApplyDisplay;
var
  P : PView;
  E : PEdEditor;
begin
  P := Desktop^.Last;
  if P <> nil then
    repeat
      if WindowOf (P) <> nil then
        begin
          E := PEdWindow (P)^.Editor;
          E^.SetState (sfActive, E^.GetState (sfActive));
          E^.DrawView;
        end;
      P := P^.Prev;
    until P = Desktop^.Last;
end;

{ Print...: the selection or the whole file to PRN, with CR LF line
  ends and a form feed at the end. }
procedure TEditApp.Print;
var
  E : PEdEditor;
  How : Integer;
  S, Stop, P : Sw_Word;
  F : File;
  Buf : array[0..511] of Char;
  N : Word;
  C, PrevCh : Char;
  Ok : Boolean;

  procedure Put (Ch : Char);
  begin
    if not Ok then Exit;
    Buf[N] := Ch;
    Inc (N);
    if N = SizeOf (Buf) then
      begin
        {$I-} BlockWrite (F, Buf, N); {$I+}
        Ok := IOResult = 0;
        N := 0;
      end;
  end;

begin
  E := CurrentEditor;
  if E = nil then
    Exit;
  How := PrintDialog (E^.SelStart <> E^.SelEnd);
  if How < 0 then
    Exit;
  if (How = prSelection) and (E^.SelStart <> E^.SelEnd) then
    begin
      S := E^.SelStart;
      Stop := E^.SelEnd;
    end
  else
    begin
      S := 0;
      Stop := E^.BufLen;
    end;
  Assign (F, 'PRN');
  {$I-} Rewrite (F, 1); {$I+}
  Ok := IOResult = 0;
  N := 0;
  PrevCh := #0;
  P := S;
  while Ok and (P < Stop) do
    begin
      C := E^.BufChar (P);
      if (C = #10) and (PrevCh <> #13) then
        Put (#13);
      Put (C);
      PrevCh := C;
      Inc (P);
    end;
  if PrevCh <> #10 then
    begin
      Put (#13);
      Put (#10);
    end;
  Put (#12);
  if Ok and (N > 0) then
    begin
      {$I-} BlockWrite (F, Buf, N); {$I+}
      Ok := IOResult = 0;
    end;
  {$I-} Close (F); {$I+}
  if IOResult <> 0 then
    Ok := False;
  if not Ok then
    ErrorBox ('The printer is not ready.');
end;

function TEditApp.ViewMenu : PMenu;
var
  Items : PMenuItem;
  P : PView;
  W : array[1..MaxWindows] of PEdWindow;
  I, N : Integer;
  S, K : String;
begin
  for I := 1 to MaxWindows do
    W[I] := nil;
  if Desktop <> nil then
    begin
      P := Desktop^.Last;
      if P <> nil then
        repeat
          if (WindowOf (P) <> nil) then
            begin
              N := PEdWindow (P)^.Number;
              if (N >= 1) and (N <= MaxWindows) then
                W[N] := PEdWindow (P);
            end;
          P := P^.Prev;
        until P = Desktop^.Last;
    end;
  Items := nil;
  for I := MaxWindows downto 1 do
    if W[I] <> nil then
      begin
        Str (I, S);
        K := 'Alt+' + S;
        S := '~' + S + '~ ' + DisplayName (W[I]^.Editor);
        Items := NewItem (S, K, kbNoKey, cmWin1 + I - 1, hcWinList, Items);
      end;
  if Items <> nil then
    Items := NewLine (Items);
  ViewMenu := NewMenu (
    NewItem ('~S~plit Windows', '', kbNoKey, cmSplit, hcSplit,
    NewItem ('~F~ull Windows', '', kbNoKey, cmFull, hcFull,
    NewItem ('~N~ext File', 'F6', kbF6, cmNext, hcNextWin,
    NewItem ('~P~revious File', 'Shift+F6', kbShiftF6, cmPrev, hcPrevWin,
    Items)))));
end;

procedure TEditApp.RebuildViewMenu;
var
  Old : PMenu;
begin
  WinListDirty := False;
  if ViewItem = nil then
    Exit;
  Old := ViewItem^.SubMenu;
  ViewItem^.SubMenu := ViewMenu;
  DisposeMenu (Old);
end;

{ -------------------------------------------------------------------- }

constructor TEditApp.Init;
var
  R : TRect;
  I : Integer;
  Opened : Boolean;
begin
  inherited Init;
  LineBreak := #13#10;
  EditorFlags := 0;
  EditorDialog := @EdEditorDialog;
  R.Assign (0, 0, 1, 1);
  Clipboard := New (PEdEditor, Init (R, nil, nil, ''));
  Clipboard^.CanUndo := False;
  Opened := False;
  for I := 1 to ArgCount do
    if (Pos ('*', Args[I]) > 0) or (Pos ('?', Args[I]) > 0) then
      OpenWithDialog (Args[I])
    else
      OpenFile (Args[I]);
  if WindowCount = 0 then
    NewFile;
  RebuildViewMenu;
end;

destructor TEditApp.Done;
begin
  if Clipboard <> nil then
    Dispose (Clipboard, Done);
  Clipboard := nil;
  inherited Done;
end;

procedure TEditApp.InitScreen;
begin
  inherited InitScreen;
  if MonoAdapter then
    AppPalette := apMonochrome
  else if ForceBW then
    AppPalette := apBlackWhite;
  if AppPalette <> apColor then
    StatusAttr := $70;
end;

function TEditApp.GetPalette : PPalette;
begin
  if AppPalette = apColor then
    GetPalette := PPalette (@ColorPal)
  else
    GetPalette := inherited GetPalette;
end;

procedure TEditApp.InitMenuBar;
var
  R : TRect;
begin
  GetExtent (R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New (PMenuBar, Init (R, NewMenu (
    NewSubMenu ('~F~ile', hcFile, NewMenu (
      NewItem ('~N~ew', '', kbNoKey, cmNew, hcNew,
      NewItem ('~O~pen...', '', kbNoKey, cmOpen, hcOpen,
      NewItem ('~S~ave', '', kbNoKey, cmSave, hcSave,
      NewItem ('Save ~A~s...', '', kbNoKey, cmSaveAs, hcSaveAs,
      NewItem ('~C~lose', 'Ctrl+F4', kbCtrlF4, cmClose, hcClose,
      NewLine (
      NewItem ('~P~rint...', '', kbNoKey, cmPrint, hcPrint,
      NewLine (
      NewItem ('E~x~it', '', kbNoKey, cmQuit, hcExit, nil)))))))))),
    NewSubMenu ('~E~dit', hcEdit, NewMenu (
      NewItem ('Cu~t~', 'Shift+Del', kbShiftDel, cmCut, hcCut,
      NewItem ('~C~opy', 'Ctrl+Ins', kbCtrlIns, cmCopy, hcCopy,
      NewItem ('~P~aste', 'Shift+Ins', kbShiftIns, cmPaste, hcPaste,
      NewItem ('Cl~e~ar', 'Del', kbNoKey, cmClear, hcClear, nil))))),
    NewSubMenu ('~S~earch', hcSearch, NewMenu (
      NewItem ('~F~ind...', '', kbNoKey, cmFind, hcFind,
      NewItem ('~R~epeat Last Find', 'F3', kbF3, cmSearchAgain, hcRepeat,
      NewItem ('~C~hange...', '', kbNoKey, cmReplace, hcChange, nil)))),
    NewSubMenu ('~V~iew', hcView, ViewMenu,
    NewSubMenu ('~O~ptions', hcOptions, NewMenu (
      NewItem ('~D~isplay...', '', kbNoKey, cmDisplay, hcDisplay, nil)),
    NewSubMenu ('~H~elp', hcHelp, NewMenu (
      NewItem ('~G~etting Started', '', kbNoKey, cmStarted, hcStarted,
      NewItem ('~K~eyboard', '', kbNoKey, cmKeys, hcKeyboard,
      NewLine (
      NewItem ('~A~bout...', '', kbNoKey, cmAbout, hcAbout, nil))))),
    nil)))))))));
  ViewItem := MenuBar^.Menu^.Items;
  while (ViewItem <> nil) and (ViewItem^.HelpCtx <> hcView) do
    ViewItem := ViewItem^.Next;
end;

procedure TEditApp.InitStatusLine;
var
  R : TRect;
begin
  GetExtent (R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New (PEdStatus, Init (R,
    NewStatusDef (0, $FFFF,
      NewStatusKey ('', kbF1, cmHelp,
      NewStatusKey ('', kbF10, cmMenu,
      NewStatusKey ('', kbF6, cmNext,
      NewStatusKey ('', kbShiftF6, cmPrev,
      NewStatusKey ('', kbCtrlF4, cmClose, nil))))),
    nil)));
end;

{ On an 83-key keyboard the cursor keys are the keypad's, and with Shift
  held (and Num Lock off) the BIOS gives their digits: Shift+Left is "4",
  Shift+Ins is "0".  Give the cursor key back; editors see the Shift. }
procedure FixKeypad (var Event : TEvent);
begin
  if (Event.ScanCode >= $47) and (Event.ScanCode <= $53) and
     (Event.CharCode in ['0'..'9', '.']) and
     (Event.KeyShift and $03 <> 0) and (Mem[$40:$17] and $20 = 0) then
    case Event.ScanCode of
      $52: Event.KeyCode := kbShiftIns;
      $53: Event.KeyCode := kbShiftDel;
    else
      Event.KeyCode := Word (Event.ScanCode) shl 8;
    end;
end;

procedure TEditApp.GetEvent (var Event : TEvent);
var
  Down : Boolean;
begin
  FlushScreen;
  inherited GetEvent (Event);
  if TestActive and (Event.What = evNothing) then
    TestNext;
  if Event.What = evKeyDown then
    begin
      FixKeypad (Event);
      AltUsed := True;
      if Event.KeyShift and $08 <> 0 then
        AltDown := True;   { Alt+key: not Alt on its own }
    end
  else if Event.What = evNothing then
    begin
      { Alt pressed and released on its own opens the menus. }
      Down := Mem[$40:$17] and $08 <> 0;
      if Down and not AltDown then
        begin
          AltDown := True;
          AltUsed := False;
        end
      else if AltDown and not Down then
        begin
          AltDown := False;
          if not AltUsed and (TopView = PView (@Self)) then
            begin
              Event.What := evCommand;
              Event.Command := cmMenu;
              Event.InfoPtr := nil;
            end;
        end;
    end;
  { FreeVision's TProgram.GetEvent leaves this out, so the status line's
    keys (F1) would not work in dialog boxes. }
  if (Event.What = evKeyDown) and (StatusLine <> nil) then
    StatusLine^.HandleEvent (Event);
  if (Event.What = evCommand) and (Event.Command = cmHelp) then
    begin
      ClearEvent (Event);
      if not InHelp then
        begin
          InHelp := True;
          ShowHelp (htStarted);
          InHelp := False;
        end;
    end;
end;

procedure TEditApp.HandleEvent (var Event : TEvent);
var
  Tabs : Sw_Word;
  Bars : Boolean;
begin
  inherited HandleEvent (Event);
  if Event.What <> evCommand then
    Exit;
  case Event.Command of
    cmNew:     NewFile;
    cmOpen:    OpenWithDialog ('*.TXT');
    cmPrint:   Print;
    cmSplit:   begin Split := True; Arrange; end;
    cmFull:    begin Split := False; Arrange; end;
    cmDisplay:
      begin
        Tabs := TabStops;
        Bars := ScrollBarsOn;
        if DisplayDialog (Tabs, Bars) then
          begin
            TabStops := Tabs;
            ScrollBarsOn := Bars;
            ApplyDisplay;
          end;
      end;
    cmStarted: ShowHelp (htStarted);
    cmKeys:    ShowHelp (htKeyboard);
    cmAbout:   AboutBox (Version);
    cmWin1..cmWin1 + MaxWindows - 1:
      Message (Desktop, evBroadcast, cmSelectWindowNum,
               Pointer (LongInt (Event.Command - cmWin1 + 1)));
  else
    Exit;
  end;
  ClearEvent (Event);
end;

procedure TEditApp.Idle;
var
  E : PEdEditor;
begin
  inherited Idle;
  if TopView <> PView (@Self) then
    Exit;
  if WindowCount = 0 then
    NewFile;
  if WinListDirty then
    begin
      if Split then
        Arrange;
      RebuildViewMenu;
    end;
  E := CurrentEditor;
  if (E <> LastEditor) or ((E <> nil) and
     ((E^.CurPos.X <> LastPos.X) or (E^.CurPos.Y <> LastPos.Y))) then
    begin
      LastEditor := E;
      if E <> nil then
        LastPos := E^.CurPos;
      StatusLine^.DrawView;
    end;
end;

{ -------------------------------------------------------------------- }

procedure Usage;
begin
  WriteLn ('Usage: EDIT [/B] [/H] [/R] [[drive:][path]filename ...]');
  WriteLn ('A full-screen text editor with the menus and keys of MS-DOS EDIT.');
  WriteLn;
  WriteLn ('  filename   file(s) to edit, up to 9; one that does not exist is');
  WriteLn ('             created when saved; * or ? shows the Open dialog');
  WriteLn ('  /B         black and white (monochrome monitor, colour adapter)');
  WriteLn ('  /H         as many lines as the EGA or VGA shows (43 or 50)');
  WriteLn ('  /R         read only: view the files without changing them');
  WriteLn ('  --help     show this help (also /?, -h, -?)');
  WriteLn ('  --version  show the version');
  WriteLn;
  WriteLn ('In the editor, Alt opens the menus and F1 shows help.');
end;

function Upper (const S : String) : String;
var
  I : Integer;
  T : String;
begin
  T := S;
  for I := 1 to Length (T) do
    T[I] := UpCase (T[I]);
  Upper := T;
end;

procedure Bad (const Msg : String);
begin
  WriteLn ('edit: ', Msg);
  WriteLn ('Try ''edit --help'' for more information.');
  Halt (1);
end;

procedure ParseArgs;
var
  I : Integer;
  S, U, Keys : String;
begin
  Keys := '';
  for I := 1 to ParamCount do
    begin
      S := ParamStr (I);
      U := Upper (S);
      if (U = '--HELP') or (U = '/?') or (U = '-H') or (U = '-?') then
        begin
          Usage;
          Halt (0);
        end
      else if U = '--VERSION' then
        begin
          WriteLn ('edit (gr-dos edit16) ', Version);
          Halt (0);
        end
      else if Copy (U, 1, 12) = '--TEST-KEYS=' then
        Keys := Copy (S, 13, 255)
      else if (S <> '') and (S[1] = '/') then
        begin
          if U = '/B' then ForceBW := True
          else if U = '/H' then WantManyLines := True
          else if U = '/R' then ReadOnlyMode := True
          else if (U = '/G') or (U = '/NOHI') or (U = '/S') then
            { EDIT's: CGA snow and 8-colour monitors, short names; nothing
              to do here }
          else
            Bad ('invalid switch ' + S);
        end
      else if (S <> '') and (S[1] = '-') then
        Bad ('invalid option ' + S)
      else
        begin
          if ArgCount = MaxArgs then
            Bad ('no more than 9 files can be open');
          Inc (ArgCount);
          Args[ArgCount] := S;
        end;
    end;
  if (Keys <> '') and not TestOpen (Keys) then
    begin
      WriteLn ('edit: cannot read ', Keys);
      Halt (2);
    end;
end;

begin
  ParseArgs;
  { Starting up and an empty window take about 18 KB of the heap; with
    less than this, FreeVision fails part way through, leaving a blank
    screen.  (With the program itself, 268 KB, that is 300 KB free.) }
  if MaxAvail < MinStartHeap then
    begin
      WriteLn ('edit: not enough memory (300 KB free needed)');
      Halt (8);
    end;
  { Files are opened only to be read (saving rewrites them): open them
    read only, or a file with the read-only attribute cannot be loaded
    (the RTL's default is read/write). }
  FileMode := 0;
  ColorPal := CAppColor;
  { EDIT's colours: grey text on blue, and grey menus with white letters
    and a black bar. }
  ColorPal[2]  := #$70;   { menu text }
  ColorPal[3]  := #$78;   { menu text, disabled }
  ColorPal[4]  := #$7F;   { menu shortcut letter }
  ColorPal[5]  := #$07;   { menu bar }
  ColorPal[6]  := #$08;   { menu bar, disabled }
  ColorPal[7]  := #$0F;   { menu bar shortcut letter }
  ColorPal[13] := #$17;   { blue window: text }
  ColorPal[14] := #$71;   { blue window: selected text }
  InitSys;
  EditApp.Init;
  EditApp.Run;
  EditApp.Done;
  DoneSys;
end.
