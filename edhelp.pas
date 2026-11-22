{ edit16: the Help menu's topics, shown in a scrolling window. }

unit EdHelp;

{$mode fpc}

interface

const
  htStarted  = 1;
  htKeyboard = 2;

procedure ShowHelp (Topic : Integer);

implementation

uses
  Objects, Drivers, Views, Dialogs, App, FVConsts, EdView;

const
  StartedText : PChar =
    'The editor shows each open file in a window, between the menu bar at'#13 +
    'the top of the screen and the status line at the bottom. The status'#13 +
    'line shows the cursor''s line and column, or what a menu item does.'#13 +
    ''#13 +
    'Menus'#13 +
    '  Press and release Alt to move to the menu bar, then a highlighted'#13 +
    '  letter, or use Left and Right and press Enter. Alt plus a letter'#13 +
    '  opens that menu directly (Alt+F for File). F10 also moves to the'#13 +
    '  menu bar. Esc leaves the menus.'#13 +
    ''#13 +
    '  File     New, Open..., Save, Save As..., Close, Print..., Exit'#13 +
    '  Edit     Cut, Copy, Paste and Clear the selected text'#13 +
    '  Search   Find..., Repeat Last Find, Change...'#13 +
    '  View     Split or full windows, and the list of open files'#13 +
    '  Options  Display... (tab stops, scroll bars)'#13 +
    '  Help     Getting Started, Keyboard, About...'#13 +
    ''#13 +
    'Dialog boxes'#13 +
    '  Tab and Shift+Tab move between the fields, the arrow keys between'#13 +
    '  the choices of a field, Space checks or unchecks a box. Alt plus a'#13 +
    '  highlighted letter goes to that field. Enter does what the'#13 +
    '  highlighted button says, Esc cancels.'#13 +
    ''#13 +
    'Several files'#13 +
    '  File New and File Open... open another window each, up to nine.'#13 +
    '  F6 and Shift+F6 switch between them, Alt+1 to Alt+9 go to a file'#13 +
    '  by its number (on its window''s frame, and in the View menu), and'#13 +
    '  View Split Windows shows them all at once. Ctrl+F4 or File Close'#13 +
    '  closes one. The editor asks before it closes a file, or exits,'#13 +
    '  with changes that are not saved.'#13 +
    ''#13 +
    'Command line'#13 +
    '  EDIT [/B] [/H] [/R] [[drive:][path]filename ...]'#13 +
    ''#13 +
    '  filename  The file(s) to edit. A file that does not exist yet is'#13 +
    '            created when it is first saved. A name with * or ? in'#13 +
    '            it shows the Open dialog with that wildcard.'#13 +
    '  /B        Black and white, for a monochrome monitor on a colour'#13 +
    '            adapter.'#13 +
    '  /H        As many lines as the adapter shows (43 on an EGA, 50 on'#13 +
    '            a VGA).'#13 +
    '  /R        Read only: the files can be viewed but not changed.'#13 +
    ''#13 +
    'Limits'#13 +
    '  A file can be up to 65,280 bytes long, and a line up to 32,767'#13 +
    '  columns. Files are saved with CR LF line ends; tab characters in'#13 +
    '  a file are kept as they are.'#13 +
    ''#13 +
    'Help Keyboard lists every key. Esc closes this window.';

  KeyboardText : PChar =
    'Moving the cursor'#13 +
    '  Character left/right      Left/Right      Ctrl+S / Ctrl+D'#13 +
    '  Word left/right           Ctrl+Left/Right Ctrl+A / Ctrl+F'#13 +
    '  Line up/down              Up/Down         Ctrl+E / Ctrl+X'#13 +
    '  Start/end of line         Home/End        Ctrl+Q S / Ctrl+Q D'#13 +
    '  Start of next line        Ctrl+Enter      Ctrl+J'#13 +
    '  Top/bottom of window                      Ctrl+Q E / Ctrl+Q X'#13 +
    '  Start/end of file         Ctrl+Home/End   Ctrl+Q R / Ctrl+Q C'#13 +
    '  Set/go to bookmark 0-3                    Ctrl+K n / Ctrl+Q n'#13 +
    ''#13 +
    'Scrolling'#13 +
    '  Up/down one line          Ctrl+Up/Down    Ctrl+W / Ctrl+Z'#13 +
    '  Up/down one page          PgUp/PgDn       Ctrl+R / Ctrl+C'#13 +
    '  Left/right one window     Ctrl+PgUp/PgDn'#13 +
    ''#13 +
    'Selecting text'#13 +
    '  Hold Shift with any key that moves the cursor: Shift+Left,'#13 +
    '  Shift+Ctrl+Right, Shift+Down, Shift+PgDn, Shift+Ctrl+End ...'#13 +
    ''#13 +
    'Inserting and deleting'#13 +
    '  Insert or overtype        Ins             Ctrl+V'#13 +
    '  Delete character/selection Del            Ctrl+G'#13 +
    '  Delete character to left  Bksp            Ctrl+H'#13 +
    '  Delete rest of word                       Ctrl+T'#13 +
    '  Cut line to clipboard                     Ctrl+Y'#13 +
    '  Cut to end of line                        Ctrl+Q Y'#13 +
    '  Insert line above         Home, Ctrl+N'#13 +
    '  Insert a control character                Ctrl+P, Ctrl+key'#13 +
    '  Indent / unindent lines   Tab / Shift+Tab (with lines selected)'#13 +
    ''#13 +
    'Clipboard'#13 +
    '  Cut                       Shift+Del'#13 +
    '  Copy                      Ctrl+Ins'#13 +
    '  Paste                     Shift+Ins'#13 +
    '  Clear (no clipboard)      Del'#13 +
    ''#13 +
    'Finding and changing'#13 +
    '  Find                      Ctrl+Q F'#13 +
    '  Repeat last find          F3              Ctrl+L'#13 +
    '  Change                    Ctrl+Q A'#13 +
    ''#13 +
    'Windows and menus'#13 +
    '  Menus                     Alt (alone), F10, Alt+letter'#13 +
    '  Next/previous file        F6 / Shift+F6'#13 +
    '  File by number            Alt+1 ... Alt+9'#13 +
    '  Close file                Ctrl+F4'#13 +
    '  Help                      F1'#13 +
    ''#13 +
    'Esc closes this window.';

  MaxLines = 120;

type
  PHelpView = ^THelpView;
  THelpView = object (TScroller)
    Text  : PChar;
    Count : Sw_Integer;
    Start : array[0..MaxLines - 1] of Word;
    constructor Init (var Bounds : TRect; AVScrollBar : PScrollBar; AText : PChar);
    procedure Draw; virtual;
  end;

constructor THelpView.Init (var Bounds : TRect; AVScrollBar : PScrollBar; AText : PChar);
var
  I : Word;
begin
  inherited Init (Bounds, nil, AVScrollBar);
  Text := AText;
  Count := 0;
  I := 0;
  Start[0] := 0;
  Count := 1;
  while Text[I] <> #0 do
    begin
      if (Text[I] = #13) and (Count < MaxLines) then
        begin
          Start[Count] := I + 1;
          Inc (Count);
        end;
      Inc (I);
    end;
  SetLimit (Size.X, Count);
  GrowMode := gfGrowHiX + gfGrowHiY;
end;

procedure THelpView.Draw;
var
  B : TDrawBuffer;
  Y : Sw_Integer;
  I : Word;
  S : String;
  C : Word;
begin
  C := GetColor (1);
  for Y := 0 to Size.Y - 1 do
    begin
      MoveChar (B, ' ', C, Size.X);
      if Delta.Y + Y < Count then
        begin
          S := '';
          I := Start[Delta.Y + Y];
          while (Text[I] <> #13) and (Text[I] <> #0) and (Length (S) < 255) do
            begin
              S := S + Text[I];
              Inc (I);
            end;
          MoveStr (B, ' ' + S, C);
        end;
      WriteLine (0, Y, Size.X, 1, B);
    end;
end;

procedure ShowHelp (Topic : Integer);
var
  D  : PDialog;
  R  : TRect;
  SB : PScrollBar;
  T  : PChar;
  Title : String;
begin
  if Topic = htKeyboard then
    begin
      T := KeyboardText;
      Title := 'Keyboard';
    end
  else
    begin
      T := StartedText;
      Title := 'Getting Started';
    end;
  Desktop^.GetExtent (R);
  D := New (PDialog, Init (R, Title));
  D^.HelpCtx := hcDialog;
  R.Assign (D^.Size.X - 1, 1, D^.Size.X, D^.Size.Y - 1);
  SB := New (PScrollBar, Init (R));
  D^.Insert (SB);
  R.Assign (1, 1, D^.Size.X - 1, D^.Size.Y - 1);
  D^.Insert (New (PHelpView, Init (R, SB, T)));
  D^.SelectNext (False);
  Application^.ExecuteDialog (D, nil);
end;

end.
