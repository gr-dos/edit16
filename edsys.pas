{ edit16: machine-level setup that FreeVision and the Free Pascal RTL get
  wrong, or leave out, on XT-class hardware.

  Video: the RTL's msdos video driver asks INT 10h AX=1130h (an EGA BIOS
  call) for the number of rows.  A CGA or MDA BIOS does not have it, and
  the row count then comes from an uninitialised register.  It also
  resets the video mode on exit, picking a CGA mode even on an MDA.  The
  driver is wrapped here: rows come from the BIOS data area only when an
  EGA or VGA is present (otherwise 25), the MDA's B000h segment is used
  in mode 7, and a request for the mode already in use does nothing.
  FreeVision copies its screen buffer to the display (UpdateScreen,
  comparing all 2,000 cells) after each view draws itself, so opening a
  dialog box did it dozens of times.  Each time, if anything had changed
  it copied the whole buffer, 4,000 bytes, to the display and again to
  its copy of what is shown, which is most of the time of a keystroke on
  an XT.  Here UpdateScreen only notes that the screen has changed;
  FlushScreen, called before the program reads the next event, copies
  once, and only the changed part of each row.

  Keyboard: in FPC 3.2.2 the msdos keyboard driver puts the shift state
  into each key event as (mem[$40:$17] and $f) shl 16, which is computed
  in 16 bits and so is always 0 (fixed upstream after 3.2.2, commit
  469a14a6).  FreeVision then never sees Shift with a key: Shift+arrows
  do not select, and its Shift+Ins, Shift+Del and Ctrl+Ins fix-ups for
  101-key keyboards never apply.  The driver is wrapped here to add the
  BIOS shift flags to each event.  (FreeVision's GetShiftState has the
  same truncation in the RTL's generic code, so it stays 0; the editor
  uses the event's KeyShift instead.)

  DOS: Ctrl+C and Ctrl+Break are ignored (INT 23h), and a critical error
  (drive not ready, printer off line, write protected disk) fails the
  DOS call instead of asking "Abort, Retry, Fail?" over the editor's
  screen (INT 24h); the program reports the error itself. }

unit EdSys;

{$mode fpc}

interface

var
  { Set before the video is started (by FreeVision's TApplication.Init). }
  WantManyLines : Boolean;   { /H: 43 or 50 rows on an EGA or VGA }

  { Known once the video has started. }
  MonoAdapter   : Boolean;   { MDA or Hercules (BIOS mode 7) }
  EgaOrBetter   : Boolean;
  ChangedRows   : Boolean;   { /H took effect; undone by DoneSys }

procedure InitSys;
procedure DoneSys;

{ Copies FreeVision's screen buffer to the display, if it has changed. }
procedure FlushScreen;

implementation

uses
  Dos, Video, Keyboard, Mouse;

var
  SysDriver, OurDriver : TVideoDriver;
  SysKbd, OurKbd       : TKeyboardDriver;
  OldInt23, OldInt24   : Pointer;
  Installed            : Boolean;
  Dirty, DirtyForce    : Boolean;

procedure Int23Handler; assembler; nostackframe;
asm
  iret
end;

{ AL = 3: fail the DOS call (DOS 3.1 and later). }
procedure Int24Handler; assembler; nostackframe;
asm
  mov al, 3
  iret
end;

function DetectEga : Boolean;
var
  R : Registers;
begin
  R.AX := $1200;
  R.BX := $FF10;   { BL=10h: get EGA information; unchanged if no EGA }
  Intr($10, R);
  DetectEga := R.BL <> $10;
end;

procedure OurInit;
var
  R    : Registers;
  Mode : Byte;
  Rows : Word;
begin
  R.AX := $0F00;
  Intr($10, R);
  Mode := R.AL;
  if R.AH < 80 then
    begin
      { 40-column modes: switch to the matching 80-column one. }
      if Mode = 1 then Mode := 3 else Mode := 2;
      R.AX := Mode;
      Intr($10, R);
    end;
  MonoAdapter := Mode = 7;
  EgaOrBetter := DetectEga;
  if WantManyLines and EgaOrBetter and not MonoAdapter then
    begin
      R.AX := $1112;   { load the 8x8 font: 43 rows on EGA, 50 on VGA }
      R.BX := 0;
      Intr($10, R);
      ChangedRows := True;
    end;
  Rows := 25;
  if EgaOrBetter then
    begin
      Rows := Mem[$40:$84] + 1;
      if (Rows < 25) or (Rows > 60) then
        Rows := 25;
    end;
  Video.ScreenWidth := 80;
  Video.ScreenHeight := Rows;
  { Modes 0 and 2 are colour burst off, 7 is the MDA. }
  Video.ScreenColor := not (Mode in [0, 2, 7]);
  SysDriver.InitDriver;
  if MonoAdapter then
    VideoSeg := SegB000
  else
    VideoSeg := SegB800;
end;

function OurSetVideoMode (const Mode : TVideoMode) : Boolean;
begin
  if (Mode.Col = Video.ScreenWidth) and (Mode.Row = Video.ScreenHeight) and
     (Mode.Color = Video.ScreenColor) then
    OurSetVideoMode := True
  else
    OurSetVideoMode := SysDriver.SetVideoMode (Mode);
end;

procedure OurUpdateScreen (Force : Boolean);
begin
  Dirty := True;
  if Force then
    DirtyForce := True;
end;

{ The index of the first of Count words at which A and B differ, or
  Count if they are the same. }
function FirstDiff (A, B : Pointer; Count : Word) : Word; assembler;
asm
  push ds
  push si
  push di
  mov cx, Count
  mov bx, cx
  jcxz @done
  lds si, A
  les di, B
  cld
  repe cmpsw
  je @done
  sub bx, cx
  dec bx
@done:
  mov ax, bx
  pop di
  pop si
  pop ds
end;

{ One more than the index of the last of Count words at which A and B
  differ, or 0 if they are the same. }
function LastDiff (A, B : Pointer; Count : Word) : Word; assembler;
asm
  push ds
  push si
  push di
  xor ax, ax
  mov cx, Count
  jcxz @done
  lds si, A
  les di, B
  mov bx, cx
  dec bx
  shl bx, 1
  add si, bx
  add di, bx
  std
  repe cmpsw
  cld
  je @done
  mov ax, cx
  inc ax
@done:
  pop di
  pop si
  pop ds
end;

procedure FlushScreen;
var
  Row, Off, F, L, W : Word;
  Hidden : Boolean;
begin
  if not Dirty then
    Exit;
  Dirty := False;
  if DirtyForce then
    begin
      DirtyForce := False;
      SysDriver.UpdateScreen (True);
      Exit;
    end;
  W := Video.ScreenWidth;
  Hidden := False;
  Off := 0;
  for Row := 1 to Video.ScreenHeight do
    begin
      F := FirstDiff (@VideoBuf^[Off], @OldVideoBuf^[Off], W);
      if F < W then
        begin
          L := F + LastDiff (@VideoBuf^[Off + F], @OldVideoBuf^[Off + F], W - F);
          if not Hidden then
            begin
              HideMouse;
              Hidden := True;
            end;
          MoveData (Seg (VideoBuf^), Ofs (VideoBuf^) + (Off + F) * 2,
                    VideoSeg, (Off + F) * 2, (L - F) * 2);
          Move (VideoBuf^[Off + F], OldVideoBuf^[Off + F], (L - F) * 2);
        end;
      Inc (Off, W);
    end;
  if Hidden then
    ShowMouse;
end;

procedure OurDone;
begin
  FlushScreen;
  SysDriver.DoneDriver;
end;

function BiosShift : TKeyEvent;
begin
  BiosShift := TKeyEvent (Mem[$40:$17] and $0F) shl 16;
end;

function OurGetKeyEvent : TKeyEvent;
begin
  OurGetKeyEvent := (SysKbd.GetKeyEvent () and $FF00FFFF) or BiosShift;
end;

function OurPollKeyEvent : TKeyEvent;
var
  K : TKeyEvent;
begin
  K := SysKbd.PollKeyEvent ();
  if K <> 0 then
    K := (K and $FF00FFFF) or BiosShift;
  OurPollKeyEvent := K;
end;

procedure InitSys;
begin
  GetKeyboardDriver (SysKbd);
  OurKbd := SysKbd;
  OurKbd.GetKeyEvent := @OurGetKeyEvent;
  OurKbd.PollKeyEvent := @OurPollKeyEvent;
  SetKeyboardDriver (OurKbd);
  GetVideoDriver (SysDriver);
  OurDriver := SysDriver;
  OurDriver.InitDriver := @OurInit;
  OurDriver.SetVideoMode := @OurSetVideoMode;
  OurDriver.UpdateScreen := @OurUpdateScreen;
  OurDriver.DoneDriver := @OurDone;
  SetVideoDriver (OurDriver);
  GetIntVec ($23, OldInt23);
  GetIntVec ($24, OldInt24);
  SetIntVec ($23, Pointer (@Int23Handler));
  SetIntVec ($24, Pointer (@Int24Handler));
  Installed := True;
end;

procedure DoneSys;
var
  R : Registers;
begin
  if not Installed then
    Exit;
  SetIntVec ($23, OldInt23);
  SetIntVec ($24, OldInt24);
  if ChangedRows then
    begin
      R.AX := 3;   { back to 80x25 }
      Intr($10, R);
      ChangedRows := False;
    end;
  Installed := False;
end;

end.
