{ edit16: the hidden test mode, used by tests/run.sh.

  EDIT --test-keys=FILE ... types the keystrokes in FILE, one each time
  the program would otherwise be idle, and can write what is on the
  screen to a file.  A key is put in the BIOS keyboard buffer, with the
  BIOS shift flags set for its Shift, Ctrl or Alt, so it reaches the
  editor the way a key typed on the keyboard does (INT 16h, FPC's
  keyboard driver, FreeVision's GetKeyEvent).  FILE holds tokens
  separated by blanks or line ends:

    "text"          types text (no " inside)
    Enter Esc Tab Bksp Del Ins Home End PgUp PgDn Up Down Left Right
    Space F1 .. F12 a key; any single printable character is that key
    Shift+K Ctrl+K Alt+K   with a modifier (combinations as on a PC:
                    Ctrl+Left, Shift+Del, Alt+F, Ctrl+Q, Shift+F6 ...);
                    the modifier is held down from before the key is
                    typed until it has been handled
    Alt             Alt pressed and released alone (activates the menus)
    #nnnn           a key code in hex (scan code * 100h + character);
                    Shift+#nnnn holds Shift down too
    dump            writes the screen's characters to NAME.Sn, where NAME
                    is FILE's name without its extension and n = 1, 2, ...
                    (one line per row, trailing blanks removed)
    ticks           appends the BIOS timer (18.2 ticks a second) since the
                    test began to NAME.T, one number a line, for timing
    ; ...           a comment to the end of the line

  When FILE runs out the program stops with exit status 3, so a test
  that forgets to leave (or is stuck in a dialog) is seen as one. }

unit EdTest;

{$mode fpc}

interface

uses
  Drivers;

var
  TestActive : Boolean;

{ Opens the script; False if it cannot be read. }
function TestOpen (const Name : String) : Boolean;

{ Called when the program is idle (no key waiting): releases the
  modifiers of the last key and types the next one, or makes a dump. }
procedure TestNext;

implementation

uses
  Video, FVConsts;

const
  BufMax = 4096;

var
  Script   : array[0..BufMax - 1] of Char;
  ScriptLen, ScriptPos : Word;
  DumpNo   : Word;
  Quoted   : String;   { the rest of a "text" token being typed }
  QuotePos : Byte;
  Held     : Byte;      { BIOS shift flags held down for the last key }
  Pending  : Word;      { a key to type once its modifiers are down }
  AltPhase : Boolean;   { "Alt": pressed, to be released next time }
  DumpBase : String;
  StartTicks : LongInt;

function TestOpen (const Name : String) : Boolean;
var
  F : File;
  N : Word;
begin
  TestOpen := False;
  Assign (F, Name);
  {$I-} Reset (F, 1); {$I+}
  if IOResult <> 0 then
    Exit;
  N := 0;
  {$I-} BlockRead (F, Script, BufMax, N); {$I+}
  Close (F);
  if IOResult <> 0 then
    Exit;
  ScriptLen := N;
  ScriptPos := 0;
  DumpBase := Name;
  N := Length (DumpBase);
  while (N > 0) and not (DumpBase[N] in ['.', '\', ':']) do
    Dec (N);
  if (N > 0) and (DumpBase[N] = '.') then
    DumpBase[0] := Chr (N - 1);
  StartTicks := MemL[$40:$6C];
  TestActive := True;
  TestOpen := True;
end;

function NextToken (var T : String) : Boolean;
var
  C : Char;
begin
  T := '';
  NextToken := False;
  repeat
    while (ScriptPos < ScriptLen) and (Script[ScriptPos] <= ' ') do
      Inc (ScriptPos);
    if ScriptPos >= ScriptLen then
      Exit;
    if Script[ScriptPos] = ';' then
      begin
        while (ScriptPos < ScriptLen) and not (Script[ScriptPos] in [#10, #13]) do
          Inc (ScriptPos);
        C := ';';
      end
    else
      C := #0;
  until C = #0;
  if Script[ScriptPos] = '"' then
    begin
      T := '"';
      Inc (ScriptPos);
      while (ScriptPos < ScriptLen) and (Script[ScriptPos] <> '"') do
        begin
          T := T + Script[ScriptPos];
          Inc (ScriptPos);
        end;
      Inc (ScriptPos);
    end
  else
    while (ScriptPos < ScriptLen) and (Script[ScriptPos] > ' ') do
      begin
        T := T + Script[ScriptPos];
        Inc (ScriptPos);
      end;
  NextToken := True;
end;

const
  { BIOS scan codes of A..Z }
  LetterScan : array['A'..'Z'] of Byte = (
    $1E, $30, $2E, $20, $12, $21, $22, $23, $17, $24, $25, $26, $32,
    $31, $18, $19, $10, $13, $1F, $14, $16, $2F, $11, $2D, $15, $2C);

function CharKey (C : Char) : Word;
begin
  case C of
    'a'..'z': CharKey := LetterScan[UpCase (C)] shl 8 or Ord (C);
    'A'..'Z': CharKey := LetterScan[C] shl 8 or Ord (C);
    '1'..'9': CharKey := (Ord (C) - Ord ('1') + 2) shl 8 or Ord (C);
    '0':      CharKey := $0B30;
    ' ':      CharKey := $3920;
  else
    CharKey := Ord (C);
  end;
end;

function HexValue (const S : String; var V : Word) : Boolean;
var
  I : Byte;
  D : Word;
begin
  HexValue := False;
  V := 0;
  if S = '' then
    Exit;
  for I := 1 to Length (S) do
    begin
      case UpCase (S[I]) of
        '0'..'9': D := Ord (S[I]) - Ord ('0');
        'A'..'F': D := Ord (UpCase (S[I])) - Ord ('A') + 10;
      else
        Exit;
      end;
      V := V * 16 + D;
    end;
  HexValue := True;
end;

{ The key code for a named key with the given modifiers, or 0. }
function NamedKey (Name : String; Shift, Ctrl, Alt : Boolean) : Word;
var
  K, N : Word;
  I    : Byte;
  C    : Char;
begin
  NamedKey := 0;
  K := 0;
  for I := 1 to Length (Name) do
    Name[I] := UpCase (Name[I]);
  if Length (Name) = 1 then
    begin
      C := Name[1];
      if Alt then
        begin
          if C in ['0'..'9'] then
            begin
              if C = '0' then K := $8100
              else K := kbAlt1 + (Ord (C) - Ord ('1')) shl 8;
            end
          else
            K := GetAltCode (C);
        end
      else if Ctrl and (C in ['A'..'Z']) then
        K := LetterScan[C] shl 8 or (Ord (C) - $40)
      else if not Ctrl then
        K := CharKey (C);
      NamedKey := K;
      Exit;
    end;
  if (Name[1] = 'F') and (Length (Name) <= 3) and (Name[2] in ['0'..'9']) then
    begin
      N := Ord (Name[2]) - Ord ('0');
      if Length (Name) = 3 then
        N := N * 10 + Ord (Name[3]) - Ord ('0');
      if (N >= 1) and (N <= 10) then
        begin
          if Alt then K := $6800 + (N - 1) shl 8
          else if Ctrl then K := $5E00 + (N - 1) shl 8
          else if Shift then K := $5400 + (N - 1) shl 8
          else K := $3B00 + (N - 1) shl 8;
        end
      else if N = 11 then
        K := $8500
      else if N = 12 then
        K := $8600;
      NamedKey := K;
      Exit;
    end;
  if Name = 'ENTER' then
    begin if Ctrl then K := kbCtrlEnter else K := kbEnter; end
  else if Name = 'ESC' then K := kbEsc
  else if Name = 'SPACE' then K := $3920
  else if Name = 'TAB' then
    begin if Shift then K := kbShiftTab else K := kbTab; end
  else if Name = 'BKSP' then
    begin if Ctrl then K := kbCtrlBack else K := kbBack; end
  else if Name = 'INS' then
    begin
      { what a 101-key keyboard's BIOS gives; the shift flags say the
        rest }
      if Ctrl then K := $9200 else K := kbIns;
    end
  else if Name = 'DEL' then
    begin
      if Ctrl then K := $9300 else K := kbDel;
    end
  else if Name = 'HOME' then
    begin if Ctrl then K := kbCtrlHome else K := kbHome; end
  else if Name = 'END' then
    begin if Ctrl then K := kbCtrlEnd else K := kbEnd; end
  else if Name = 'PGUP' then
    begin if Ctrl then K := kbCtrlPgUp else K := kbPgUp; end
  else if Name = 'PGDN' then
    begin if Ctrl then K := kbCtrlPgDn else K := kbPgDn; end
  else if Name = 'UP' then
    begin if Ctrl then K := kbCtrlUp else K := kbUp; end
  else if Name = 'DOWN' then
    begin if Ctrl then K := kbCtrlDown else K := kbDown; end
  else if Name = 'LEFT' then
    begin if Ctrl then K := kbCtrlLeft else K := kbLeft; end
  else if Name = 'RIGHT' then
    begin if Ctrl then K := kbCtrlRight else K := kbRight; end;
  NamedKey := K;
end;

procedure Fail (const Why, Token : String);
begin
  WriteLn ('edit: test script: ', Why, ': ', Token);
  Halt (4);
end;

procedure Dump;
var
  F       : Text;
  Name    : String;
  X, Y, L : Word;
  Line    : String;
begin
  Inc (DumpNo);
  Str (DumpNo, Name);
  Name := DumpBase + '.S' + Name;
  Assign (F, Name);
  {$I-} Rewrite (F); {$I+}
  if IOResult <> 0 then
    Fail ('cannot write', Name);
  for Y := 0 to ScreenHeight - 1 do
    begin
      Line := '';
      for X := 0 to ScreenWidth - 1 do
        Line := Line + Chr (Lo (VideoBuf^[Y * ScreenWidth + X]));
      L := Length (Line);
      while (L > 0) and (Line[L] = ' ') do
        Dec (L);
      Line[0] := Chr (L);
      WriteLn (F, Line);
    end;
  Close (F);
end;

procedure Ticks;
var
  F : Text;
begin
  Assign (F, DumpBase + '.T');
  {$I-} Append (F); {$I+}
  if IOResult <> 0 then
    begin
      {$I-} Rewrite (F); {$I+}
      if IOResult <> 0 then
        Fail ('cannot write', DumpBase + '.T');
    end;
  WriteLn (F, MemL[$40:$6C] - StartTicks);
  Close (F);
end;

procedure Press (Flags : Byte);
begin
  Mem[$40:$17] := (Mem[$40:$17] and not $0F) or Flags;
  Held := Flags;
end;

{ Puts a key code in the BIOS keyboard buffer. }
procedure Stuff (K : Word);
var
  Head, Tail, Next, First, Last : Word;
begin
  First := MemW[$40:$80];
  Last := MemW[$40:$82];
  if (First = 0) or (Last <= First) then
    begin
      First := $1E;   { an XT BIOS has no pointers: the standard buffer }
      Last := $3E;
    end;
  Head := MemW[$40:$1A];
  Tail := MemW[$40:$1C];
  Next := Tail + 2;
  if Next >= Last then
    Next := First;
  if Next = Head then
    Fail ('keyboard buffer full', '');
  MemW[$40:Tail] := K;
  MemW[$40:$1C] := Next;
end;

procedure TestNext;
var
  T, Rest     : String;
  Shift, Ctrl, Alt : Boolean;
  K           : Word;
  P           : Byte;
  Mods        : String;
begin
  if Pending <> 0 then
    begin
      Stuff (Pending);
      Pending := 0;
      Exit;
    end;
  if Held <> 0 then
    Press (0);
  if AltPhase then
    begin
      AltPhase := False;   { Alt released }
      Exit;
    end;
  if QuotePos < Length (Quoted) then
    begin
      Inc (QuotePos);
      Stuff (CharKey (Quoted[QuotePos]));
      Exit;
    end;
  if not NextToken (T) then
    begin
      WriteLn ('edit: test script ended');
      Halt (3);
    end;
  if T[1] = '"' then
    begin
      Quoted := Copy (T, 2, 255);
      QuotePos := 0;
      Exit;   { typed from the next call on }
    end;
  if T = 'dump' then
    begin
      Dump;
      Exit;
    end;
  if T = 'ticks' then
    begin
      Ticks;
      Exit;
    end;
  if T = 'Alt' then
    begin
      Press ($08);
      AltPhase := True;
      Exit;
    end;
  Shift := False; Ctrl := False; Alt := False;
  Rest := T;
  repeat
    P := Pos ('+', Rest);
    if (P > 1) and (P < Length (Rest)) then
      begin
        Mods := Copy (Rest, 1, P - 1);
        Delete (Rest, 1, P);
        if Mods = 'Shift' then Shift := True
        else if Mods = 'Ctrl' then Ctrl := True
        else if Mods = 'Alt' then Alt := True
        else Fail ('bad modifier', T);
      end
    else
      P := 0;
  until P = 0;
  if Rest[1] = '#' then
    begin
      if not HexValue (Copy (Rest, 2, 255), K) then
        Fail ('bad key code', T);
    end
  else
    K := NamedKey (Rest, Shift, Ctrl, Alt);
  if K = 0 then
    Fail ('unknown key', T);
  P := 0;
  if Shift then P := P or $02;   { left Shift }
  if Ctrl then P := P or $04;
  if Alt then P := P or $08;
  if P <> 0 then
    begin
      Press (P);        { the modifiers go down first ... }
      Pending := K;     { ... and the key is typed the next time }
    end
  else
    Stuff (K);
end;

end.
