{ edit16: the editor view, its window, and the status line.

  TEdEditor is FreeVision's TFileEditor with MS-DOS EDIT's keyboard:
  ConvertEvent is replaced, so FreeVision's own WordStar tables (Ctrl+O,
  Ctrl+B, Ctrl+J ... which reformat or jump in ways EDIT does not) are
  never used.  Find and Change are done here, not by FreeVision, so
  that they wrap around the end of the file as EDIT's do.

  FreeVision keeps the text in one buffer with a gap at the cursor.
  Everything here reads it through BufChar and positions (0..BufLen),
  never through pointer differences, which FPC 3.2.2 miscompiles in the
  large model (see fv/README.md). }

unit EdView;

{$mode fpc}

interface

uses
  Objects, Drivers, Views, Menus, Editors, FVConsts;

const
  { Commands of our own, above FreeVision's. }
  cmEdNextLine  = 1100;   { Ctrl+Enter, Ctrl+J }
  cmEdWinLeft   = 1101;   { Ctrl+PgUp }
  cmEdWinRight  = 1102;   { Ctrl+PgDn }
  cmEdTab       = 1103;
  cmEdUntab     = 1104;   { Shift+Tab }
  cmEdCutLine   = 1105;   { Ctrl+Y }
  cmEdCutToEnd  = 1106;   { Ctrl+Q Y }
  cmEdLiteral   = 1107;   { Ctrl+P, then a key }
  cmEdNoOp      = 1108;

  { Help contexts.  The status line shows a hint for each menu item. }
  hcEditor      = 0;
  hcDialog      = 2;
  hcMenuFirst   = 1000;
  hcFile = 1000; hcNew = 1001; hcOpen = 1002; hcSave = 1003; hcSaveAs = 1004;
  hcClose = 1005; hcPrint = 1006; hcExit = 1007;
  hcEdit = 1010; hcCut = 1011; hcCopy = 1012; hcPaste = 1013; hcClear = 1014;
  hcSearch = 1020; hcFind = 1021; hcRepeat = 1022; hcChange = 1023;
  hcView = 1030; hcSplit = 1031; hcFull = 1032; hcNextWin = 1033;
  hcPrevWin = 1034; hcWinList = 1035;
  hcOptions = 1040; hcDisplay = 1041;
  hcHelp = 1050; hcStarted = 1051; hcKeyboard = 1052; hcAbout = 1053;

  { EditorDialog codes of our own, after FreeVision's ed... ones. }
  edChangeDone  = 100;    { Change finished: "Change complete." }

  { Memory kept free when a buffer grows, for dialogs and menus. }
  MemReserve = 8192;

  { The largest file, and the longest line, FreeVision's editor takes on
    16-bit DOS (Editors.MaxBufLength and Editors.MaxLineLength). }
  MaxFileSize = MaxBufLength;

type
  PEdEditor = ^TEdEditor;
  TEdEditor = object (TFileEditor)
    UntitledNo : Integer;
    constructor Init (var Bounds : TRect; AHScrollBar, AVScrollBar : PScrollBar;
                      const AFileName : FNameStr);
    procedure ConvertEvent (var Event : TEvent); virtual;
    procedure Draw; virtual;
    procedure HandleEvent (var Event : TEvent); virtual;
    function  SetBufSize (NewSize : Sw_Word) : Boolean; virtual;
    procedure SetState (AState : Word; Enable : Boolean); virtual;
    procedure UpdateCommands; virtual;
    function  Valid (Command : Word) : Boolean; virtual;
    function  SelectedText (MaxLen : Byte) : String;
    function  WordAtCursor : String;
    procedure SelectAll;
  private
    Prefix : Char;     { #0, or Q, K or P after Ctrl+Q, Ctrl+K, Ctrl+P }
    NoDraw : Boolean;
    Shifted : Boolean; { Shift was down with the key being handled }
    function  LineStartOf (P : Sw_Word) : Sw_Word;
    function  LineEndOf (P : Sw_Word) : Sw_Word;
    function  NextLineOf (P : Sw_Word) : Sw_Word;
    function  PrevLineStart (P : Sw_Word) : Sw_Word;
    function  PtrAtCol (LineStart : Sw_Word; Col : Sw_Integer) : Sw_Word;
    function  SelMode : Byte;
    function  MatchAt (I : Sw_Word; const S : String; Opts : Word) : Boolean;
    function  FindIn (const S : String; Opts : Word; From, Upto : Sw_Word;
                      var At : Sw_Word) : Boolean;
    procedure Command (Cmd : Word);
    procedure CutRange (S, E : Sw_Word);
    procedure DoFind (Again : Boolean);
    procedure DoChange;
    procedure DoTab;
    procedure DoUntab;
    procedure IndentLines (Indent : Boolean);
    procedure WinScroll (Dir : Integer);
    procedure Redraw;
  end;

  PEdWindow = ^TEdWindow;
  { A window frame drawn quickly: FreeVision's TFrame.Draw builds every
    row of the frame at full width, then writes it, although the editor
    covers all but the two edge cells.  That was a quarter of the time of
    starting up on an XT, and of every window switch.  This one draws
    the same frame (no framed subviews are ever joined to it) but writes
    only the edges of the rows between the top and bottom.  (It does not
    show a mouse click on the close or zoom icon as * for a moment.) }
  PEdFrame = ^TEdFrame;
  TEdFrame = object (TFrame)
    procedure Draw; virtual;
  end;

  TEdWindow = object (TWindow)
    Editor : PEdEditor;
    constructor Init (var Bounds : TRect; const AFileName : FNameStr;
                      ANumber, AUntitledNo : Integer);
    destructor Done; virtual;
    procedure InitFrame; virtual;
    function  GetTitle (MaxSize : Sw_Integer) : TTitleStr; virtual;
    procedure HandleEvent (var Event : TEvent); virtual;
    procedure SizeLimits (var Min, Max : TPoint); virtual;
  end;

  PEdStatus = ^TEdStatus;
  TEdStatus = object (TStatusLine)
    procedure Draw; virtual;
  end;

var
  { Options (Options, Display...) }
  ScrollBarsOn : Boolean;
  TabStops     : Sw_Word;   { the Tab key's indent; tab characters show at 8 }
  { Find and Change options last used (efCaseSensitive, efWholeWordsOnly) }
  FindOpts     : Word;
  { Set whenever a window opens, closes or is renamed: the View menu's
    list of files is rebuilt from it. }
  WinListDirty : Boolean;
  { The status line's colours; set for monochrome by the application. }
  StatusAttr   : Byte;
  ReadOnlyMode : Boolean;   { /R }
  { The name of the file a "save it now?" question is about. }
  AskName      : String;

{ The editor of the window in front, or nil. }
function CurrentEditor : PEdEditor;

{ The file name part of a path, in capitals, or UNTITLEDn. }
function DisplayName (E : PEdEditor) : String;

{ The hint for a menu item's help context. }
function MenuHint (Ctx : Word) : String;

implementation

uses
  Dos, App;

const
  WordSet : set of Char = ['0'..'9', 'A'..'Z', 'a'..'z', '_', #128..#255];

function Min (A, B : Sw_Word) : Sw_Word;
begin
  if A < B then Min := A else Min := B;
end;

{ -------------------------------------------------------------------- }
{ TEdEditor                                                             }

constructor TEdEditor.Init (var Bounds : TRect;
                            AHScrollBar, AVScrollBar : PScrollBar;
                            const AFileName : FNameStr);
begin
  inherited Init (Bounds, AHScrollBar, AVScrollBar, nil, AFileName);
  { Tab characters show at every 8th column: FreeVision's cursor
    arithmetic (CharPos, CharPtr) assumes 8 whatever TabSize says. }
  TabSize := 8;
  AutoIndent := True;
  IsReadOnly := ReadOnlyMode;
end;

function TEdEditor.LineStartOf (P : Sw_Word) : Sw_Word;
begin
  while (P > 0) and not (BufChar (P - 1) in [#10, #13]) do
    Dec (P);
  LineStartOf := P;
end;

function TEdEditor.LineEndOf (P : Sw_Word) : Sw_Word;
begin
  while (P < BufLen) and not (BufChar (P) in [#10, #13]) do
    Inc (P);
  LineEndOf := P;
end;

{ The start of the line after P's, or BufLen on the last line. }
function TEdEditor.NextLineOf (P : Sw_Word) : Sw_Word;
begin
  P := LineEndOf (P);
  if P < BufLen then
    begin
      if (BufChar (P) = #13) and (P + 1 < BufLen) and (BufChar (P + 1) = #10) then
        Inc (P, 2)
      else
        Inc (P);
    end;
  NextLineOf := P;
end;

{ The start of the line before the one that starts at P. }
function TEdEditor.PrevLineStart (P : Sw_Word) : Sw_Word;
begin
  if (P > 0) and (BufChar (P - 1) = #10) then
    Dec (P);
  if (P > 0) and (BufChar (P - 1) = #13) then
    Dec (P);
  PrevLineStart := LineStartOf (P);
end;

{ The position in the line starting at LineStart nearest screen column
  Col (tabs counted as the editor shows them). }
function TEdEditor.PtrAtCol (LineStart : Sw_Word; Col : Sw_Integer) : Sw_Word;
var
  P : Sw_Word;
  X : Sw_Integer;
  C : Char;
begin
  P := LineStart;
  X := 0;
  while P < BufLen do
    begin
      C := BufChar (P);
      if C in [#10, #13] then
        Break;
      if C = #9 then
        X := (X div TabSize + 1) * TabSize
      else
        Inc (X);
      if X > Col then
        Break;
      Inc (P);
    end;
  PtrAtCol := P;
end;

function TEdEditor.SelMode : Byte;
begin
  if Shifted then
    SelMode := 1   { smExtend }
  else
    SelMode := 0;
end;

{ TEditor.Draw finds the first line in the window by moving, a line at
  a time, from the last one it drew (DrawLine, DrawPtr).  After a jump,
  such as a Find from the top that matched at the end of a big file, it
  went through every line of the file in between, twice (the selection
  is drawn before the window scrolls to it): 15 seconds on an XT.  It
  now starts from whichever line it knows is nearest: the last one
  drawn, the cursor's or the first. }
procedure TEdEditor.Draw;

  procedure Nearer (Line : Sw_Integer; P : Sw_Word);
  begin
    if Abs (Line - Delta.Y) < Abs (DrawLine - Delta.Y) then
      begin
        DrawLine := Line;
        DrawPtr := P;
      end;
  end;

begin
  if NoDraw then
    Exit;
  if DrawLine <> Delta.Y then
    begin
      Nearer (0, 0);
      Nearer (CurPos.Y, LineStartOf (CurPtr));
    end;
  inherited Draw;
end;

procedure TEdEditor.Redraw;
begin
  NoDraw := False;
  TrackCursor (not CursorVisible);
  DrawView;
end;

function TEdEditor.SetBufSize (NewSize : Sw_Word) : Boolean;
begin
  { A buffer grows in 4 KB steps, and ReAllocMem needs the new block
    while the old one is still in use. }
  if (NewSize > BufSize) and
     (MaxAvail < LongInt (NewSize) + MinBufLength + MemReserve) then
    SetBufSize := False
  else
    SetBufSize := inherited SetBufSize (NewSize);
end;

{ What TFileEditor.UpdateCommands does, but changing only the commands
  whose state differs.  FreeVision's sets each of them after every key,
  and each change is several operations on a 32-byte set, done by byte
  loops in the RTL: that was 40% of the time of a cursor move. }
procedure TEdEditor.UpdateCommands;
var
  Active : Boolean;

  procedure Put (Cmd : Word; Enable : Boolean);
  begin
    Enable := Enable and Active;
    if CommandEnabled (Cmd) <> Enable then
      SetCmdState (Cmd, Enable);
  end;

begin
  Active := State and sfActive <> 0;
  Put (cmUndo, (DelCount <> 0) or (InsCount <> 0));
  if Clipboard <> @Self then
    begin
      Put (cmCut, SelStart <> SelEnd);
      Put (cmCopy, SelStart <> SelEnd);
      Put (cmPaste, (Clipboard <> nil) and
                    (Clipboard^.SelStart <> Clipboard^.SelEnd));
    end;
  Put (cmClear, SelStart <> SelEnd);
  Put (cmFind, True);
  Put (cmReplace, True);
  Put (cmSearchAgain, True);
  Put (cmSave, True);
  Put (cmSaveAs, True);
  Put (cmSaveDone, True);
end;

procedure TEdEditor.SetState (AState : Word; Enable : Boolean);
begin
  inherited SetState (AState, Enable);
  if not ScrollBarsOn then
    begin
      if HScrollBar <> nil then HScrollBar^.Hide;
      if VScrollBar <> nil then VScrollBar^.Hide;
    end;
end;

function TEdEditor.Valid (Command : Word) : Boolean;
begin
  if (Command <> cmValid) and Modified then
    AskName := DisplayName (@Self);
  Valid := inherited Valid (Command);
end;

{ EDIT's keys.  Everything that is not typing text becomes a command. }
procedure TEdEditor.ConvertEvent (var Event : TEvent);
var
  Cmd  : Word;
  K    : Word;
  Ch   : Char;
  Info : Word;
begin
  if Event.What <> evKeyDown then
    begin
      if Event.What <> evCommand then
        Shifted := False;
      Exit;
    end;
  { Shift as it was when the key was pressed (FreeVision's own check
    reads it again later, from the BIOS). }
  Shifted := Event.KeyShift and (kbLeftShift or kbRightShift) <> 0;
  K := Event.KeyCode;
  Ch := Event.CharCode;
  Cmd := 0;
  Info := 0;
  if Prefix <> #0 then
    begin
      if Prefix = 'P' then
        begin
          Cmd := cmEdLiteral;
          Info := Ord (Ch);
          if Ch = #0 then Cmd := cmEdNoOp;
        end
      else
        begin
          if (Ch >= #1) and (Ch <= #26) then
            Ch := Chr (Ord (Ch) + $40);
          Ch := UpCase (Ch);
          if Prefix = 'Q' then
            case Ch of
              '0'..'3': Cmd := cmJumpMark0 + Ord (Ch) - Ord ('0');
              'A': Cmd := cmReplace;
              'F': Cmd := cmFind;
              'E': Cmd := cmHomePage;
              'X': Cmd := cmEndPage;
              'S': Cmd := cmLineStart;
              'D': Cmd := cmLineEnd;
              'R': Cmd := cmTextStart;
              'C': Cmd := cmTextEnd;
              'Y': Cmd := cmEdCutToEnd;
            else
              Cmd := cmEdNoOp;
            end
          else   { K }
            case Ch of
              '0'..'3': Cmd := cmSetMark0 + Ord (Ch) - Ord ('0');
            else
              Cmd := cmEdNoOp;
            end;
        end;
      Prefix := #0;
    end
  else
    case K of
      kbLeft:      Cmd := cmCharLeft;
      kbRight:     Cmd := cmCharRight;
      kbUp:        Cmd := cmLineUp;
      kbDown:      Cmd := cmLineDown;
      kbHome:      Cmd := cmLineStart;
      kbEnd:       Cmd := cmLineEnd;
      kbPgUp:      Cmd := cmPageUp;
      kbPgDn:      Cmd := cmPageDown;
      kbCtrlLeft:  Cmd := cmWordLeft;
      kbCtrlRight: Cmd := cmWordRight;
      kbCtrlHome:  Cmd := cmTextStart;
      kbCtrlEnd:   Cmd := cmTextEnd;
      kbCtrlPgUp:  Cmd := cmEdWinLeft;
      kbCtrlPgDn:  Cmd := cmEdWinRight;
      kbCtrlUp:    Cmd := cmScrollUp;
      kbCtrlDown:  Cmd := cmScrollDown;
      kbIns:       Cmd := cmInsMode;
      kbDel:       Cmd := cmDelChar;
      kbShiftDel:  Cmd := cmCut;
      kbCtrlIns:   Cmd := cmCopy;
      kbShiftIns:  Cmd := cmPaste;
      kbBack:      Cmd := cmBackSpace;
      kbEnter:     Cmd := cmNewLine;
      kbCtrlEnter: Cmd := cmEdNextLine;
      kbTab:       Cmd := cmEdTab;
      kbShiftTab:  Cmd := cmEdUntab;
    else
      if (Ch >= #1) and (Ch <= #26) and (K <> kbEsc) then
        case Chr (Ord (Ch) + $40) of
          'A': Cmd := cmWordLeft;
          'C': Cmd := cmPageDown;
          'D': Cmd := cmCharRight;
          'E': Cmd := cmLineUp;
          'F': Cmd := cmWordRight;
          'G': Cmd := cmDelChar;
          'H': Cmd := cmBackSpace;
          'I': Cmd := cmEdTab;
          'J': Cmd := cmEdNextLine;
          'K': begin Prefix := 'K'; Cmd := cmEdNoOp; end;
          'L': Cmd := cmSearchAgain;
          'M': Cmd := cmNewLine;
          'N': Cmd := cmInsertLine;
          'P': begin Prefix := 'P'; Cmd := cmEdNoOp; end;
          'Q': begin Prefix := 'Q'; Cmd := cmEdNoOp; end;
          'R': Cmd := cmPageUp;
          'S': Cmd := cmCharLeft;
          'T': Cmd := cmDelWord;
          'V': Cmd := cmInsMode;
          'W': Cmd := cmScrollUp;
          'X': Cmd := cmLineDown;
          'Y': Cmd := cmEdCutLine;
          'Z': Cmd := cmScrollDown;
        else
          Cmd := cmEdNoOp;   { Ctrl+B, Ctrl+O, Ctrl+U: not EDIT keys }
        end;
    end;
  if Cmd <> 0 then
    begin
      Event.What := evCommand;
      Event.Command := Cmd;
      Event.InfoPtr := nil;
      Event.InfoWord := Info;
    end;
end;

function IsMove (Cmd : Word) : Boolean;
begin
  case Cmd of
    cmCharLeft, cmCharRight, cmWordLeft, cmWordRight, cmLineStart,
    cmLineEnd, cmLineUp, cmLineDown, cmPageUp, cmPageDown, cmTextStart,
    cmTextEnd, cmHomePage, cmEndPage:
      IsMove := True;
  else
    IsMove := False;
  end;
end;

function IsChange (Cmd : Word) : Boolean;
begin
  case Cmd of
    cmCut, cmPaste, cmClear, cmUndo, cmNewLine, cmBackSpace, cmDelChar,
    cmDelWord, cmDelStart, cmDelEnd, cmDelLine, cmInsertLine, cmTabKey,
    cmReplace, cmEdTab, cmEdUntab, cmEdCutLine, cmEdCutToEnd, cmEdLiteral:
      IsChange := True;
  else
    IsChange := False;
  end;
end;

{ Runs one of FreeVision's editor commands. }
procedure TEdEditor.Command (Cmd : Word);
var
  E : TEvent;
begin
  E.What := evCommand;
  E.Command := Cmd;
  E.InfoPtr := nil;
  inherited HandleEvent (E);
end;

procedure TEdEditor.CutRange (S, E : Sw_Word);
begin
  if E <= S then
    Exit;
  SetSelect (S, E, True);
  Command (cmCut);
end;

procedure TEdEditor.HandleEvent (var Event : TEvent);
var
  Ch   : Char;
  P    : Sw_Word;
begin
  ConvertEvent (Event);
  if IsReadOnly then
    if ((Event.What = evCommand) and IsChange (Event.Command)) or
       ((Event.What = evKeyDown) and (Event.CharCode >= #32)) then
      begin
        ClearEvent (Event);
        Exit;
      end;
  if Event.What = evCommand then
    begin
      case Event.Command of
        cmFind:        DoFind (False);
        cmSearchAgain: DoFind (True);
        cmReplace:     DoChange;
        cmEdNoOp:      ;
        cmPaste:
          { FreeVision would paste "nothing" over the selection }
          if (Clipboard <> nil) and (Clipboard <> @Self) and
             (Clipboard^.SelStart <> Clipboard^.SelEnd) then
            begin
              inherited HandleEvent (Event);
              Exit;
            end;
        cmEdNextLine:
          begin
            P := NextLineOf (CurPtr);
            if P > LineEndOf (CurPtr) then
              begin
                SetCurPtr (P, 0);
                TrackCursor (False);
              end;
          end;
        cmEdWinLeft:   WinScroll (-1);
        cmEdWinRight:  WinScroll (1);
        cmEdTab:       DoTab;
        cmEdUntab:     DoUntab;
        cmEdCutLine:   CutRange (LineStartOf (CurPtr), NextLineOf (CurPtr));
        cmEdCutToEnd:  CutRange (CurPtr, LineEndOf (CurPtr));
        cmEdLiteral:
          begin
            Ch := Chr (Lo (Event.InfoWord));
            InsertText (@Ch, 1, False);
            TrackCursor (not CursorVisible);
          end;
      else
        begin
          if Shifted and IsMove (Event.Command) and not Selecting then
            begin
              Selecting := True;
              inherited HandleEvent (Event);
              Selecting := False;
            end
          else
            inherited HandleEvent (Event);
          Exit;
        end;
      end;
      ClearEvent (Event);
      Exit;
    end;
  inherited HandleEvent (Event);
end;

procedure TEdEditor.WinScroll (Dir : Integer);
var
  X, Col : Sw_Integer;
begin
  X := Delta.X + Dir * Size.X;
  if X < 0 then X := 0;
  Col := CurPos.X + Dir * Size.X;
  if Col < 0 then Col := 0;
  ScrollTo (X, Delta.Y);
  SetCurPtr (PtrAtCol (LineStartOf (CurPtr), Col), SelMode);
  TrackCursor (False);
end;

procedure TEdEditor.DoTab;
var
  N : Sw_Word;
  Spaces : String;
begin
  if (SelStart <> SelEnd) and
     (LineStartOf (SelStart) <> LineStartOf (SelEnd)) then
    begin
      IndentLines (True);
      Exit;
    end;
  N := TabStops - Sw_Word (CurPos.X) mod TabStops;
  if Overwrite and (SelStart = SelEnd) and
     (PtrAtCol (LineStartOf (CurPtr), CurPos.X + N) <> LineEndOf (CurPtr)) then
    begin
      SetCurPtr (PtrAtCol (LineStartOf (CurPtr), CurPos.X + N), SelMode);
      TrackCursor (False);
      Exit;
    end;
  FillChar (Spaces[1], N, ' ');
  Spaces[0] := Chr (N);
  InsertText (@Spaces[1], N, False);
  TrackCursor (not CursorVisible);
end;

procedure TEdEditor.DoUntab;
var
  S, P : Sw_Word;
  N, K : Sw_Word;
begin
  if SelStart <> SelEnd then
    begin
      IndentLines (False);
      Exit;
    end;
  { Without a selection: delete the blanks before the cursor back to the
    previous tab stop, when there is nothing else before it. }
  S := LineStartOf (CurPtr);
  P := S;
  while (P < CurPtr) and (BufChar (P) = ' ') do
    Inc (P);
  if (P <> CurPtr) or (CurPtr = S) then
    Exit;
  N := Sw_Word (CurPos.X) mod TabStops;
  if N = 0 then N := TabStops;
  K := CurPtr - S;
  if N > K then N := K;
  SetSelect (CurPtr - N, CurPtr, True);
  DeleteSelect;
  TrackCursor (False);
end;

{ Tab and Shift+Tab on a selection: indent or unindent each line it
  covers by one tab stop, and select those lines. }
procedure TEdEditor.IndentLines (Indent : Boolean);
var
  First, Last, L, P : Sw_Word;
  Lines, I, N : Sw_Word;
  Spaces : String;
begin
  First := LineStartOf (SelStart);
  if (SelEnd > SelStart) and (LineStartOf (SelEnd) = SelEnd) then
    Last := PrevLineStart (SelEnd)
  else
    Last := LineStartOf (SelEnd);
  if Last < First then Last := First;
  Lines := 1;
  L := Last;
  while L > First do
    begin
      L := PrevLineStart (L);
      Inc (Lines);
    end;
  FillChar (Spaces[1], TabStops, ' ');
  Spaces[0] := Chr (TabStops);
  NoDraw := True;
  L := Last;
  for I := 1 to Lines do
    begin
      if Indent then
        begin
          if LineEndOf (L) > L then   { blank lines stay empty }
            begin
              SetSelect (L, L, True);
              if not InsertText (@Spaces[1], TabStops, False) then
                Break;
            end;
        end
      else
        begin
          P := L;
          N := 0;
          if (P < BufLen) and (BufChar (P) = #9) then
            N := 1
          else
            while (N < TabStops) and (P + N < BufLen) and (BufChar (P + N) = ' ') do
              Inc (N);
          if N > 0 then
            begin
              SetSelect (L, L + N, True);
              DeleteSelect;
            end;
        end;
      if L > First then
        L := PrevLineStart (L);
    end;
  P := First;
  for I := 1 to Lines do
    P := NextLineOf (P);
  SetSelect (First, P, False);
  Redraw;
end;

function TEdEditor.SelectedText (MaxLen : Byte) : String;
var
  S : String;
  P : Sw_Word;
begin
  S := '';
  if (SelEnd > SelStart) and (SelEnd - SelStart <= MaxLen) then
    for P := SelStart to SelEnd - 1 do
      begin
        if BufChar (P) in [#10, #13] then
          begin
            S := '';
            Break;
          end;
        S := S + BufChar (P);
      end;
  SelectedText := S;
end;

{ The word at or just before the cursor, for the Find dialog. }
function TEdEditor.WordAtCursor : String;
var
  S, E : Sw_Word;
  W : String;
begin
  W := SelectedText (80);
  if W = '' then
    begin
      S := CurPtr;
      if (S >= BufLen) or not (BufChar (S) in WordSet) then
        if (S > 0) and (BufChar (S - 1) in WordSet) then
          Dec (S);
      while (S > 0) and (BufChar (S - 1) in WordSet) do
        Dec (S);
      E := S;
      while (E < BufLen) and (BufChar (E) in WordSet) and (E - S < 80) do
        Inc (E);
      while S < E do
        begin
          W := W + BufChar (S);
          Inc (S);
        end;
    end;
  WordAtCursor := W;
end;

procedure TEdEditor.SelectAll;
begin
  SetSelect (0, BufLen, False);
end;

function TEdEditor.MatchAt (I : Sw_Word; const S : String; Opts : Word) : Boolean;
var
  K : Byte;
  L : Sw_Word;
begin
  MatchAt := False;
  L := Length (S);
  if Opts and efCaseSensitive <> 0 then
    begin
      for K := 1 to L do
        if BufChar (I + K - 1) <> S[K] then
          Exit;
    end
  else
    for K := 1 to L do
      if UpCase (BufChar (I + K - 1)) <> UpCase (S[K]) then
        Exit;
  if Opts and efWholeWordsOnly <> 0 then
    begin
      if (I > 0) and (BufChar (I - 1) in WordSet) then
        Exit;
      if (I + L < BufLen) and (BufChar (I + L) in WordSet) then
        Exit;
    end;
  MatchAt := True;
end;

{ The index of the first of Count bytes at P that is C1 or C2, or Count
  if there is none: 5 instructions a byte. }
function Scan2 (P : Pointer; Count : Word; C1, C2 : Char) : Word; assembler;
asm
  push ds
  push si
  mov cx, Count
  mov bx, cx
  jcxz @done
  mov dl, C1
  mov dh, C2
  lds si, P
  cld
@next:
  lodsb
  cmp al, dl
  je @found
  cmp al, dh
  je @found
  loop @next
  jmp @done
@found:
  dec cx
  sub bx, cx
  dec bx
@done:
  mov ax, bx
  pop si
  pop ds
end;

{ The first match of S that starts at or after From and ends by Upto.
  The buffer is scanned directly, in its two runs either side of the
  gap at CurPtr, for S's first character (in either case unless
  efCaseSensitive); only there is the rest compared.  (Calling BufChar
  for every byte took 20 seconds for 60 KB on an XT.) }
function TEdEditor.FindIn (const S : String; Opts : Word;
                           From, Upto : Sw_Word; var At : Sw_Word) : Boolean;
var
  Last, L, A, B, J, Shift : Sw_Word;
  C1, C2 : Char;
  Run : Integer;
  Buf : PEditBuffer;
begin
  FindIn := False;
  L := Length (S);
  if (L = 0) or (Upto > BufLen) or (Upto < L) then
    Exit;
  Last := Upto - L;   { the last position a match can start at }
  if From > Last then
    Exit;
  C1 := S[1];
  C2 := C1;
  if Opts and efCaseSensitive = 0 then
    begin
      C1 := UpCase (C1);
      if C1 in ['A'..'Z'] then
        C2 := Chr (Ord (C1) + 32);
    end;
  Buf := Buffer;
  for Run := 1 to 2 do
    begin
      { positions A..B, at Buf^[A + Shift]..Buf^[B + Shift] }
      if Run = 1 then
        begin
          if (CurPtr = 0) or (From >= CurPtr) then
            Continue;
          A := From;
          B := CurPtr - 1;
          if B > Last then B := Last;
          Shift := 0;
        end
      else
        begin
          A := From;
          if A < CurPtr then A := CurPtr;
          B := Last;
          if A > B then
            Continue;
          Shift := GapLen;
        end;
      J := A + Shift;
      while J <= B + Shift do
        begin
          Inc (J, Scan2 (@Buf^[J], B + Shift - J + 1, C1, C2));
          if J > B + Shift then
            Break;
          if MatchAt (J - Shift, S, Opts) then
            begin
              At := J - Shift;
              FindIn := True;
              Exit;
            end;
          Inc (J);
        end;
    end;
end;

procedure TEdEditor.DoFind (Again : Boolean);
var
  Rec : TFindDialogRec;
  At  : Sw_Word;
  Found : Boolean;
begin
  if not Again or (FindStr = '') then
    begin
      Rec.Find := WordAtCursor;
      if Rec.Find = '' then
        Rec.Find := FindStr;
      Rec.Options := FindOpts;
      if EditorDialog (edFind, @Rec) = cmCancel then
        Exit;
      FindStr := Rec.Find;
      FindOpts := Rec.Options and (efCaseSensitive or efWholeWordsOnly);
    end;
  if FindStr = '' then
    Exit;
  { From the cursor to the end, then from the top. }
  Found := FindIn (FindStr, FindOpts, CurPtr, BufLen, At);
  if not Found then
    Found := FindIn (FindStr, FindOpts, 0, Min (BufLen, CurPtr + Length (FindStr) - 1), At);
  if Found then
    begin
      SetSelect (At, At + Length (FindStr), False);
      TrackCursor (not CursorVisible);
    end
  else
    EditorDialog (edSearchFailed, nil);
end;

procedure TEdEditor.DoChange;
var
  Rec     : TReplaceDialogRec;
  At, P, Bound : Sw_Word;
  LF, LR  : Sw_Word;
  Count   : Word;
  Found, Wrapped, Verify, Stop, Finished : Boolean;
  Where   : TPoint;
begin
  Rec.Find := WordAtCursor;
  if Rec.Find = '' then
    Rec.Find := FindStr;
  Rec.Replace := ReplaceStr;
  Rec.Options := FindOpts;
  if EditorDialog (edReplace, @Rec) = cmCancel then
    Exit;
  FindStr := Rec.Find;
  ReplaceStr := Rec.Replace;
  FindOpts := Rec.Options and (efCaseSensitive or efWholeWordsOnly);
  Verify := Rec.Options and efPromptOnReplace <> 0;
  if FindStr = '' then
    Exit;
  LF := Length (FindStr);
  LR := Length (ReplaceStr);
  Count := 0;
  Found := False;
  if not Verify then
    begin
      { Change All: every match in the file, drawn once at the end. }
      NoDraw := True;
      P := 0;
      while FindIn (FindStr, FindOpts, P, BufLen, At) do
        begin
          Found := True;
          SetSelect (At, At + LF, False);
          if not InsertText (@ReplaceStr[1], LR, False) then
            Break;
          Inc (Count);
          P := At + LR;
        end;
      Redraw;
    end
  else
    begin
      { Find and Verify: from the cursor to the end, then from the top
        to the cursor.  On the way round, a match must start before
        Bound, where the cursor was (so one the cursor was in is found,
        as Find finds it), and Bound moves with the text changed before
        it.  A match is never offered twice: one changed or skipped on
        the first pass starts at or after Bound. }
      Bound := CurPtr;
      P := CurPtr;
      Wrapped := False;
      Stop := False;
      Finished := False;
      repeat
        if not Wrapped then
          begin
            if not FindIn (FindStr, FindOpts, P, BufLen, At) then
              begin
                Wrapped := True;
                P := 0;
                Continue;
              end;
          end
        else if (P >= Bound) or
                not FindIn (FindStr, FindOpts, P,
                            Min (BufLen, Bound + LF - 1), At) then
          Break;
        Found := True;
        SetSelect (At, At + LF, False);
        TrackCursor (not CursorVisible);
        Where.X := CurPos.X - Delta.X;
        Where.Y := CurPos.Y - Delta.Y;
        MakeGlobal (Where, Where);
        case EditorDialog (edReplacePrompt, @Where) of
          cmYes:
            begin
              if not InsertText (@ReplaceStr[1], LR, False) then
                Stop := True
              else
                begin
                  Inc (Count);
                  if Wrapped then
                    { At < Bound, so At + LF >= Bound only for the match
                      the cursor was in, the last there can be.  Else
                      Bound - LF > At >= 0: no unsigned underflow. }
                    if At + LF >= Bound then
                      Finished := True
                    else
                      Bound := (Bound - LF) + LR;
                end;
              P := At + LR;
            end;
          cmNo:
            P := At + LF;
        else
          Stop := True;
        end;
      until Stop or Finished;
      TrackCursor (not CursorVisible);
      if Stop then
        Exit;
    end;
  if not Found then
    EditorDialog (edSearchFailed, nil)
  else
    EditorDialog (edChangeDone, nil);
end;

{ -------------------------------------------------------------------- }
{ TEdWindow                                                             }

procedure TEdFrame.Draw;
const
  { [active] top, sides, bottom: left, fill, right }
  Chars : array[Boolean, 0..2] of String[3] =
    ((#218#196#191, #179' '#179, #192#196#217),
     (#201#205#187, #186' '#186, #200#205#188));
var
  CFrame, CTitle, FA, HA, TA : Word;
  Active : Boolean;
  W, L, I : Sw_Integer;
  B : TDrawBuffer;
  Title : TTitleStr;
  Win : PWindow;
  Min, Max : TPoint;

  procedure Line (const C : String);
  var
    X : Sw_Integer;
  begin
    B[0] := FA + Ord (C[1]);
    for X := 1 to W - 2 do
      B[X] := FA + Ord (C[2]);
    B[W - 1] := FA + Ord (C[3]);
  end;

begin
  Win := PWindow (Owner);
  if State and sfDragging <> 0 then
    begin
      CFrame := $0505;
      CTitle := $0005;
      Active := False;
    end
  else if State and sfActive = 0 then
    begin
      CFrame := $0101;
      CTitle := $0002;
      Active := False;
    end
  else
    begin
      CFrame := $0503;
      CTitle := $0004;
      Active := True;
    end;
  CFrame := GetColor (CFrame);
  CTitle := GetColor (CTitle);
  FA := Lo (CFrame) shl 8;   { frame }
  HA := Hi (CFrame) shl 8;   { its icons }
  TA := Lo (CTitle) shl 8;   { title }
  W := Size.X;
  L := W - 10;
  if Win^.Flags and (wfClose + wfZoom) <> 0 then
    Dec (L, 6);
  Line (Chars[Active, 0]);
  if (Win^.Number <> wnNoNumber) and (Win^.Number < 10) then
    begin
      Dec (L, 4);
      if Win^.Flags and wfZoom <> 0 then
        I := 7
      else
        I := 3;
      B[W - I] := FA + Win^.Number + $30;
    end;
  Title := Win^.GetTitle (L);
  if Title <> '' then
    begin
      L := Length (Title);
      if L > W - 10 then
        L := W - 10;
      if L < 0 then
        L := 0;
      I := (W - L) shr 1;
      B[I - 1] := TA + Ord (' ');
      for W := 1 to L do
        B[I + W - 1] := TA + Ord (Title[W]);
      B[I + L] := TA + Ord (' ');
      W := Size.X;
    end;
  if Active then
    begin
      if Win^.Flags and wfClose <> 0 then
        begin
          B[2] := FA + Ord ('[');
          B[3] := HA + $FE;
          B[4] := FA + Ord (']');
        end;
      if Win^.Flags and wfZoom <> 0 then
        begin
          B[W - 5] := FA + Ord ('[');
          B[W - 4] := HA + 24;
          B[W - 3] := FA + Ord (']');
          Owner^.SizeLimits (Min, Max);
          if (Owner^.Size.X = Max.X) and (Owner^.Size.Y = Max.Y) then
            B[W - 4] := HA + 18;
        end;
    end;
  WriteLine (0, 0, W, 1, B);
  if Size.Y > 2 then
    begin
      B[0] := FA + Ord (Chars[Active, 1][1]);
      B[1] := FA + Ord (Chars[Active, 1][3]);
      WriteLine (0, 1, 1, Size.Y - 2, B[0]);
      WriteLine (W - 1, 1, 1, Size.Y - 2, B[1]);
    end;
  Line (Chars[Active, 2]);
  if Active and (Win^.Flags and wfGrow <> 0) then
    begin
      B[W - 2] := HA + 196;
      B[W - 1] := HA + 217;
    end;
  WriteLine (0, Size.Y - 1, W, 1, B);
end;

procedure TEdWindow.InitFrame;
var
  R : TRect;
begin
  GetExtent (R);
  Frame := New (PEdFrame, Init (R));
end;

constructor TEdWindow.Init (var Bounds : TRect; const AFileName : FNameStr;
                            ANumber, AUntitledNo : Integer);
var
  HScrollBar, VScrollBar : PScrollBar;
  R : TRect;
begin
  inherited Init (Bounds, '', ANumber);
  Options := Options or ofTileable;
  R.Assign (1, Size.Y - 1, Size.X - 1, Size.Y);
  HScrollBar := New (PScrollBar, Init (R));
  HScrollBar^.Hide;
  Insert (HScrollBar);
  R.Assign (Size.X - 1, 1, Size.X, Size.Y - 1);
  VScrollBar := New (PScrollBar, Init (R));
  VScrollBar^.Hide;
  Insert (VScrollBar);
  GetExtent (R);
  R.Grow (-1, -1);
  Editor := New (PEdEditor, Init (R, HScrollBar, VScrollBar, AFileName));
  Editor^.UntitledNo := AUntitledNo;
  Insert (Editor);
  WinListDirty := True;
end;

destructor TEdWindow.Done;
begin
  inherited Done;
  WinListDirty := True;
end;

function TEdWindow.GetTitle (MaxSize : Sw_Integer) : TTitleStr;
begin
  GetTitle := DisplayName (Editor);
end;

procedure TEdWindow.HandleEvent (var Event : TEvent);
begin
  inherited HandleEvent (Event);
  if (Event.What = evBroadcast) and (Event.Command = cmUpdateTitle) then
    begin
      Frame^.DrawView;
      WinListDirty := True;
      ClearEvent (Event);
    end;
end;

procedure TEdWindow.SizeLimits (var Min, Max : TPoint);
begin
  inherited SizeLimits (Min, Max);
  Min.X := 20;
end;

{ -------------------------------------------------------------------- }
{ The status line                                                       }

function MenuHint (Ctx : Word) : String;
begin
  case Ctx of
    hcFile:     MenuHint := 'Commands for files';
    hcNew:      MenuHint := 'Opens a new, untitled file';
    hcOpen:     MenuHint := 'Loads a file from disk';
    hcSave:     MenuHint := 'Saves the current file';
    hcSaveAs:   MenuHint := 'Saves the current file under a new name';
    hcClose:    MenuHint := 'Closes the current file';
    hcPrint:    MenuHint := 'Prints the current file or the selected text';
    hcExit:     MenuHint := 'Exits the editor and returns to DOS';
    hcEdit:     MenuHint := 'Commands for the clipboard';
    hcCut:      MenuHint := 'Deletes the selected text and copies it to the clipboard';
    hcCopy:     MenuHint := 'Copies the selected text to the clipboard';
    hcPaste:    MenuHint := 'Inserts the clipboard''s text at the cursor';
    hcClear:    MenuHint := 'Deletes the selected text without copying it';
    hcSearch:   MenuHint := 'Commands for finding and changing text';
    hcFind:     MenuHint := 'Finds the text you give';
    hcRepeat:   MenuHint := 'Finds the next match of the text last searched for';
    hcChange:   MenuHint := 'Finds text and changes it to other text';
    hcView:     MenuHint := 'Commands for the open files';
    hcSplit:    MenuHint := 'Shows every open file at once, the screen split between them';
    hcFull:     MenuHint := 'Gives each open file the whole screen again';
    hcNextWin:  MenuHint := 'Switches to the next open file';
    hcPrevWin:  MenuHint := 'Switches to the previous open file';
    hcWinList:  MenuHint := 'Switches to this file';
    hcOptions:  MenuHint := 'Commands for the editor''s settings';
    hcDisplay:  MenuHint := 'Changes the tab stops and the scroll bars';
    hcHelp:     MenuHint := 'Commands for help';
    hcStarted:  MenuHint := 'How to use the menus, dialog boxes and command line';
    hcKeyboard: MenuHint := 'Lists the editor''s keys';
    hcAbout:    MenuHint := 'Shows the version and license';
  else
    MenuHint := '';
  end;
end;

function CurrentEditor : PEdEditor;
var
  V : PView;
begin
  CurrentEditor := nil;
  if (Desktop = nil) then
    Exit;
  V := Desktop^.Current;
  if (V <> nil) and (TypeOf (V^) = TypeOf (TEdWindow)) then
    CurrentEditor := PEdWindow (V)^.Editor;
end;

function DisplayName (E : PEdEditor) : String;
var
  D : DirStr;
  N : NameStr;
  X : ExtStr;
  S : String;
  I : Byte;
begin
  if E^.FileName = '' then
    begin
      Str (E^.UntitledNo, S);
      DisplayName := 'UNTITLED' + S;
      Exit;
    end;
  FSplit (E^.FileName, D, N, X);
  S := N + X;
  for I := 1 to Length (S) do
    S[I] := UpCase (S[I]);
  DisplayName := S;
end;

function Pad (N : LongInt; Width : Byte) : String;
var
  S : String;
begin
  Str (N, S);
  while Length (S) < Width do
    S := '0' + S;
  Pad := S;
end;

procedure TEdStatus.Draw;
var
  B : TDrawBuffer;
  S, P : String;
  E : PEdEditor;
  X, I : Sw_Integer;
  C : Word;
begin
  if HelpCtx >= hcMenuFirst then
    S := ' ' + MenuHint (HelpCtx)
  else if HelpCtx = hcDialog then
    S := ' F1=Help  Enter=Execute  Esc=Cancel  Tab=Next Field  Arrow=Next Item'
  else
    S := ' <F1=Help> Press ALT to activate menus';
  { (a loop on the local buffer: FreeVision's MoveChar and MoveStr were
    a tenth of the time of a keystroke on an XT) }
  C := StatusAttr shl 8;
  for X := 0 to Size.X - 1 do
    B[X] := C + Ord (' ');
  for X := 1 to Length (S) do
    B[X - 1] := C + Ord (S[X]);
  E := CurrentEditor;
  if (HelpCtx < hcMenuFirst) and (HelpCtx <> hcDialog) and (E <> nil) then
    begin
      P := #179' ' + Pad (E^.CurPos.Y + 1, 5) + ':' + Pad (E^.CurPos.X + 1, 3) + ' ';
      X := Size.X - Length (P);
      if X > Length (S) then
        for I := 1 to Length (P) do
          B[X + I - 1] := C + Ord (P[I]);
    end;
  WriteLine (0, 0, Size.X, 1, B);
end;

begin
  ScrollBarsOn := True;
  TabStops := 8;
  StatusAttr := $30;
end.
