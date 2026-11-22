{ edit16: dialog boxes, laid out and worded after MS-DOS EDIT's.

  EdEditorDialog replaces FreeVision's Editors.EditorDialog, which the
  editor calls for every question it asks (save changes?, file name,
  find, change, errors). }

unit EdDlg;

{$mode fpc}

interface

uses
  Objects, Drivers, Views, Dialogs, Editors, FVConsts;

const
  { Print: what to print }
  prSelection = 0;
  prDocument  = 1;

function EdEditorDialog (Dialog : Integer; Info : Pointer) : Word;

{ The file to open; Name holds the wildcard to start with. }
function OpenDialog (var Name : FNameStr) : Boolean;

{ Print... : prSelection or prDocument, or -1 if cancelled. }
function PrintDialog (HasSelection : Boolean) : Integer;

{ Options, Display... }
function DisplayDialog (var Tabs : Sw_Word; var ScrollBars : Boolean) : Boolean;

procedure ErrorBox (const Msg : String);
procedure InfoBox (const Msg : String);
procedure AboutBox (const Version : String);

implementation

uses
  Dos, App, MsgBox, StdDlg, EdView;

function Exec (D : PDialog; Data : Pointer) : Word;
begin
  D^.HelpCtx := hcDialog;
  Exec := Application^.ExecuteDialog (D, Data);
end;

procedure AddButtons (D : PDialog; Y : Sw_Integer; const Names : array of String;
                      const Cmds : array of Word; Default : Integer);
var
  I : Integer;
  W, X, Total : Sw_Integer;
  R : TRect;
  Flags : Word;
begin
  Total := 0;
  for I := 0 to High (Names) do
    Inc (Total, Length (Names[I]) + 4 + 2);
  Dec (Total, 2);
  X := (D^.Size.X - Total) div 2;
  for I := 0 to High (Names) do
    begin
      W := Length (Names[I]) + 4;
      if Pos ('~', Names[I]) > 0 then
        Dec (W, 2);
      R.Assign (X, Y, X + W, Y + 2);
      if I = Default then Flags := bfDefault else Flags := bfNormal;
      D^.Insert (New (PButton, Init (R, Names[I], Cmds[I], Flags)));
      Inc (X, W + 2);
    end;
end;

function NewDialog (W, H : Sw_Integer; const Title : String) : PDialog;
var
  R : TRect;
begin
  R.Assign (0, 0, W, H);
  NewDialog := New (PDialog, Init (R, Title));
  NewDialog^.Options := NewDialog^.Options or ofCentered;
end;

procedure ErrorBox (const Msg : String);
begin
  MessageBox (^C + Msg, nil, mfError + mfOKButton);
end;

procedure InfoBox (const Msg : String);
begin
  MessageBox (^C + Msg, nil, mfInformation + mfOKButton);
end;

procedure AboutBox (const Version : String);
var
  R : TRect;
  K : String;
begin
  Str (MemAvail div 1024, K);
  R.Assign (0, 0, 48, 12);
  R.Move ((Desktop^.Size.X - 48) div 2, (Desktop^.Size.Y - 12) div 2);
  MessageBoxRect (R,
    ^C'GR-DOS Editor'#13 +
    ^C'edit16 version ' + Version + #13#13 +
    ^C'MIT license; FreeVision is under the LGPL'#13 +
    ^C'with the Free Pascal linking exception'#13#13 +
    ^C + K + ' KB of memory free',
    nil, mfInformation + mfOKButton);
end;

{ Find: "Find What", Match Upper/Lowercase, Whole Word }
function FindDialog (var Rec : TFindDialogRec) : Word;
var
  D  : PDialog;
  R  : TRect;
  IL : PInputLine;
begin
  D := NewDialog (60, 10, 'Find');
  R.Assign (15, 2, 57, 3);
  IL := New (PInputLine, Init (R, 80));
  D^.Insert (IL);
  R.Assign (2, 2, 15, 3);
  D^.Insert (New (PLabel, Init (R, '~F~ind What:', IL)));
  R.Assign (2, 4, 57, 5);
  D^.Insert (New (PCheckBoxes, Init (R,
    NewSItem ('~M~atch Upper/Lowercase',
    NewSItem ('~W~hole Word', nil)))));
  AddButtons (D, 7, ['OK', 'Cancel', 'Help'], [cmOK, cmCancel, cmHelp], 0);
  D^.SelectNext (False);
  FindDialog := Exec (D, @Rec);
end;

{ Change: "Find What", "Change To", the options, and how }
function ChangeDialog (var Rec : TReplaceDialogRec) : Word;
var
  D  : PDialog;
  R  : TRect;
  IL : PInputLine;
  C  : Word;
begin
  D := NewDialog (62, 12, 'Change');
  R.Assign (15, 2, 59, 3);
  IL := New (PInputLine, Init (R, 80));
  D^.Insert (IL);
  R.Assign (2, 2, 15, 3);
  D^.Insert (New (PLabel, Init (R, '~F~ind What:', IL)));
  R.Assign (15, 4, 59, 5);
  IL := New (PInputLine, Init (R, 80));
  D^.Insert (IL);
  R.Assign (2, 4, 15, 5);
  D^.Insert (New (PLabel, Init (R, 'Change ~T~o:', IL)));
  R.Assign (2, 6, 59, 7);
  D^.Insert (New (PCheckBoxes, Init (R,
    NewSItem ('~M~atch Upper/Lowercase',
    NewSItem ('~W~hole Word', nil)))));
  AddButtons (D, 9, ['Find and ~V~erify', '~C~hange All', 'Cancel', 'Help'],
              [cmYes, cmNo, cmCancel, cmHelp], 0);
  D^.SelectNext (False);
  Rec.Options := Rec.Options and (efCaseSensitive or efWholeWordsOnly);
  C := Exec (D, @Rec);
  Rec.Options := Rec.Options and (efCaseSensitive or efWholeWordsOnly);
  case C of
    cmYes: Rec.Options := Rec.Options or efPromptOnReplace;
    cmNo:  Rec.Options := Rec.Options or efReplaceAll;
  end;
  ChangeDialog := C;
end;

{ Asked at each match by Find and Verify: cmYes changes it, cmNo skips
  it, cmCancel stops.  Placed away from the match at Where. }
function VerifyDialog (const Where : TPoint) : Word;
var
  D : PDialog;
  R : TRect;
  Y : Sw_Integer;
begin
  D := NewDialog (46, 7, 'Change');
  R.Assign (2, 2, 44, 3);
  D^.Insert (New (PStaticText, Init (R, ^C'Change this occurrence?')));
  AddButtons (D, 4, ['~C~hange', '~S~kip', 'Cancel', 'Help'],
              [cmYes, cmNo, cmCancel, cmHelp], 0);
  D^.Options := D^.Options and not ofCentered;
  if Where.Y < Desktop^.Size.Y div 2 then
    Y := Desktop^.Size.Y - D^.Size.Y - 1
  else
    Y := 1;
  D^.MoveTo ((Desktop^.Size.X - D^.Size.X) div 2, Y);
  VerifyDialog := Exec (D, nil);
end;

function OpenDialog (var Name : FNameStr) : Boolean;
var
  D : PFileDialog;
begin
  D := New (PFileDialog, Init (Name, 'Open', '~F~ile Name:', fdOpenButton, 100));
  OpenDialog := Exec (PDialog (D), @Name) <> cmCancel;
end;

function SaveAsDialog (var Name : FNameStr) : Word;
var
  D : PFileDialog;
  N : FNameStr;
  C : Word;
begin
  repeat
    D := New (PFileDialog, Init ('*.TXT', 'Save As', '~F~ile Name:', fdOkButton, 101));
    N := Name;
    C := Exec (PDialog (D), @N);
    if C = cmCancel then
      begin
        SaveAsDialog := cmCancel;
        Exit;
      end;
    N := FExpand (N);
    if (N <> FExpand (Name)) and (FSearch (N, '') <> '') then
      C := MessageBox (^C'File already exists.'#13^C'Overwrite?', nil,
                       mfConfirmation + mfYesNoCancel)
    else
      C := cmYes;
    if C = cmCancel then
      begin
        SaveAsDialog := cmCancel;
        Exit;
      end;
  until C = cmYes;
  Name := N;
  SaveAsDialog := cmOK;
end;

function PrintDialog (HasSelection : Boolean) : Integer;
var
  D : PDialog;
  R : TRect;
  V : Word;
begin
  D := NewDialog (40, 9, 'Print');
  R.Assign (8, 2, 32, 4);
  D^.Insert (New (PRadioButtons, Init (R,
    NewSItem ('~S~elected Text Only',
    NewSItem ('~C~omplete Document', nil)))));
  AddButtons (D, 6, ['OK', 'Cancel', 'Help'], [cmOK, cmCancel, cmHelp], 0);
  D^.SelectNext (False);
  if HasSelection then V := prSelection else V := prDocument;
  if Exec (D, @V) = cmCancel then
    PrintDialog := -1
  else
    PrintDialog := V;
end;

function DisplayDialog (var Tabs : Sw_Word; var ScrollBars : Boolean) : Boolean;
type
  TRec = packed record
    Flags : Word;
    Tabs  : String[2];
  end;
var
  D  : PDialog;
  R  : TRect;
  IL : PInputLine;
  Rec : TRec;
  N  : LongInt;
  E  : Integer;
begin
  DisplayDialog := False;
  D := NewDialog (44, 10, 'Display');
  R.Assign (4, 2, 24, 3);
  D^.Insert (New (PCheckBoxes, Init (R, NewSItem ('~S~croll Bars', nil))));
  R.Assign (18, 4, 23, 5);
  IL := New (PInputLine, Init (R, 2));
  D^.Insert (IL);
  R.Assign (4, 4, 17, 5);
  D^.Insert (New (PLabel, Init (R, '~T~ab Stops:', IL)));
  AddButtons (D, 7, ['OK', 'Cancel', 'Help'], [cmOK, cmCancel, cmHelp], 0);
  D^.SelectNext (False);
  if ScrollBars then Rec.Flags := 1 else Rec.Flags := 0;
  Str (Tabs, Rec.Tabs);
  if Exec (D, @Rec) = cmCancel then
    Exit;
  ScrollBars := Rec.Flags and 1 <> 0;
  Val (Rec.Tabs, N, E);
  if (E = 0) and (N >= 1) and (N <= 16) then
    Tabs := N
  else
    ErrorBox ('Tab stops must be from 1 to 16.');
  DisplayDialog := True;
end;

function AskSave : Word;
begin
  AskSave := MessageBox (^C + AskName + ' is not saved.'#13^C'Save it now?',
                         nil, mfConfirmation + mfYesNoCancel);
end;

function EdEditorDialog (Dialog : Integer; Info : Pointer) : Word;
begin
  EdEditorDialog := cmCancel;
  case Dialog of
    edOutOfMemory:
      ErrorBox ('Not enough memory.');
    edReadError:
      ErrorBox ('Cannot read ' + PString (Info)^);
    edWriteError, edCreateError:
      ErrorBox ('Cannot save ' + PString (Info)^);
    edSaveModify, edSaveUntitled:
      EdEditorDialog := AskSave;
    edSaveAs:
      EdEditorDialog := SaveAsDialog (FNameStr (Info^));
    edFind:
      EdEditorDialog := FindDialog (TFindDialogRec (Info^));
    edSearchFailed:
      InfoBox ('Match not found.');
    edReplace:
      EdEditorDialog := ChangeDialog (TReplaceDialogRec (Info^));
    edReplacePrompt:
      EdEditorDialog := VerifyDialog (TPoint (Info^));
    edChangeDone:
      InfoBox ('Change complete.');
  else
    EdEditorDialog := StdEditorDialog (Dialog, Info);
  end;
end;

end.
