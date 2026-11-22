# FreeVision's Editors unit, patched for 16-bit DOS

`editors.pas` is FreeVision's `Editors` unit from Free Pascal 3.2.2, with
`editors.diff` applied. The program is built with this copy instead of
the precompiled `editors.ppu` that comes with the compiler (`-Fu fv`
comes first in the `Makefile`). All the other FreeVision units are the
release's precompiled ones, unchanged.

## Provenance

| File | Source |
|---|---|
| `editors.pas` | `packages/fv/src/editors.pas` at tag `release_3_2_2` of <https://gitlab.com/freepascal.org/fpc/source>, SHA-256 `d975b352453c7fce2e14f63629a0c9177e543bd61240230340e2a489c905fea7` before patching, plus `editors.diff` |
| `platform.inc` | `packages/fv/src/platform.inc` at the same tag, unchanged (`editors.pas` includes it) |
| `COPYING.FPC` | `rtl/COPYING.FPC` at the same tag: the license of the RTL and packages |
| `COPYING` | `rtl/COPYING.txt` at the same tag: the GNU Library GPL that `COPYING.FPC` modifies |

`make check-fv` (`scripts/check-fv`) fetches the two upstream files,
checks the hash, applies `editors.diff` and compares the result with
`editors.pas`, so the copy here cannot drift from "3.2.2 plus the diff".

To change the patch: edit `editors.pas`, regenerate `editors.diff` with
`diff -u` against the upstream file (labels `a/packages/fv/src/editors.pas`
and `b/packages/fv/src/editors.pas`), and run `make check-fv`.

## License

FreeVision, like the rest of the Free Pascal run-time library and
packages, is under the GNU Library GPL with the exception in
`COPYING.FPC`: it may be linked into a program under any license. The
patched `editors.pas` is a modified version of the library. Its source,
and the patch, are this directory. The release archive carries
`COPYING.FPC` as `LICENSE.fv`.

## The patch

There are six changes. Each is marked `edit16:` in the source. The
first four fix bugs; the last two make it fast enough on an XT.

### 1. Pointer differences in the large model (code generation)

`TEditor.LineEnd` and `TEditor.LineStart` return pointer differences
such as `LineEnd := pc - (pchar(Buffer) + GapLen)`. With far data
pointers (the compact, large and huge models), FPC 3.2.2 computes the
difference in 32 bits and stores all 32 bits into the 16-bit `Sw_Word`
result, so the high word overwrites the caller's saved BP:

```
sub  bx,ax
sbb  cx,dx
mov  word [bp-2],bx   ; result
mov  word [bp],cx     ; overwrites the saved BP
...
pop  bp               ; BP = 0
```

The caller's epilogue then does `mov sp,bp` with BP = 0 and returns
through garbage. This happens on the first draw of any editor, so an
unpatched editor hangs the machine. The fix computes the difference from
the offsets, in 16 bits. It is exact because an editor's buffer is one
heap block, in one segment:

```pascal
LineEnd := Sw_Word (Ofs (pc^) - Ofs (Buffer^) - GapLen);
```

The medium model is not affected (its data pointers are 16-bit), but it
leaves only about 16 KB of heap once a file is open, too little for
several files. See gr-dos/edit16#1 for the investigation.

The rest of edit16 does not compute pointer differences at all. It reads
the text through `BufChar` and positions.

### 2. Files over 32 KB could not be loaded

`TFileEditor.LoadFile` reads the file with
`BlockRead (F, ..., FSize, FRead)` where `FRead` is a `Sw_Integer`. On
16-bit targets that is a signed 16-bit integer, so for a file over 32,767
bytes it holds a negative number, `FRead <> FSize`, and the editor
reports a read error. `FRead` is now a `Sw_Word`. With this fix, files up
to `MaxBufLength` (65,280 bytes) load.

### 3. Trailing blanks deleted on every cursor move

After nearly every command, `TEditor.HandleEvent` calls
`Remove_EOL_Spaces` once the buffer has been modified. That deletes the
blanks at the end of the cursor's line. So typing `a ` and pressing an
arrow key deleted the blank, and moving through a modified file deleted
the trailing blanks of each line visited. This was meant for word wrap
("there can be no spaces at the end of a line, or wordwrap doesn't work
properly"). It now does nothing unless word wrap is on. edit16 never
turns word wrap on, since MS-DOS EDIT has none.

### 4. Lines longer than 1,024 columns overran the stack

`TEditor.DrawLines` formats each line into a stack buffer of
`MaxLineLength` (1,024) cells, from column 0 up to the right edge of the
window. Once the window scrolled far enough right that its right edge
was past column 1,024 (End on a long line was enough), `FormatLine`
wrote past the buffer and the program hung. Now, when the window is
scrolled that far, the line is formatted starting from a character near
the window's left edge. That character is one that starts on a tab stop,
so tab characters still line up. Lines of any length then display and
edit correctly. FreeVision's column arithmetic is 16-bit and signed, so
the practical limit is 32,767 columns.

### 5. FormatLine fills with FillWord

`FormatLine`, which every drawn line goes through, filled the rest of a
line with blanks one cell at a time through a far pointer. It now calls
the RTL's `FillWord` (`rep stosw`). This was a tenth of the time of
drawing a window on an XT.

### 6. CountLines and GetLimits in assembler

`CountLines` (run whenever the cursor moves, over the text it moves
across) and `GetLimits` (run over the whole file when it is loaded)
were Pascal loops of about 15 instructions a byte: on an XT, 3 seconds
for Ctrl+End or for loading a 60 KB file. They are now one assembler
routine, `ScanLines`, with the same results: a CR LF or LF CR pair is one
line break, and the longest line is counted in bytes. The Pascal
`GetLimits` also read past the end of its buffer when the buffer ended in
such a pair. The new routine does not.

## Other FreeVision behaviour edit16 works around without patching

- `LineBreak` defaults to LF only (`{$define UNIXLF}`), so Enter would
  insert bare LFs. It is a typed constant and is set to CR LF at startup.
- `EditorFlags` defaults to making `.bak` backups on every save. EDIT
  does not, so it is set to 0.
- `TEditor.Search` uses `Scan` and `IScan`, whose loop
  (`numb < size - len`) misses a match in the last `len` bytes of the
  buffer, and it does not wrap around. edit16 has its own search
  (`TEdEditor.FindIn`).
- `CharPos` and `CharPtr` place the cursor as if tabs were 8 columns
  wide, whatever `TabSize` says. Tab characters are therefore always
  shown at every 8th column. EDIT's Tab Stops option sets how far the
  Tab key indents instead.
- `IsReadOnly` is declared but never checked. `/R` is implemented in
  `TEdEditor.HandleEvent`.
- FPC's msdos video driver gets the number of rows from INT 10h
  AX=1130h. That is an EGA BIOS call: on a CGA or MDA the row count
  comes from an uninitialised register. The driver is wrapped in
  `edsys.pas`.
- The same driver's `UpdateScreen` compares the whole screen buffer and,
  if anything differs, copies all 4,000 bytes to the display and to its
  copy. FreeVision calls it after each view draws. `edsys.pas` makes
  `UpdateScreen` only note the change, and copies the changed part of
  each row once before the next event is read.
- FPC 3.2.2's msdos keyboard driver computes the shift state it puts in
  each key event in 16 bits, so it is always 0. FreeVision then never
  sees Shift with a key, so Shift+arrows don't select. Upstream fixed
  this after 3.2.2 (commit `469a14a6`, "return the proper shift state
  in the i8086-msdos keyboard unit"). `edsys.pas` wraps the driver to
  add the BIOS shift flags. `GetShiftState` has the same truncation,
  so the editor uses the event's `KeyShift` instead.
- `TEditor.UpdateCommands` enables or disables ten commands after every
  key, each a few operations on a 32-byte set done by byte loops in the
  RTL. That was 40% of the time of a cursor move. `TEdEditor` overrides
  it to change only the commands whose state differs.
- `TFrame.Draw` builds and writes every row of a window's frame at full
  width, though the editor covers the inside. `TEdFrame` draws the same
  frame but writes only the edge cells of the middle rows.
- `TEditor.Draw` finds the window's first line by moving a line at a
  time from the last line drawn. After a jump, such as a Find from the
  top to the end of a big file, that went through the whole file twice.
  `TEdEditor.Draw` first starts it from whichever known line is nearest
  (the last drawn, the cursor's, or the first).

## Newer compilers

No newer compiler is used, and none has been tested. Free Pascal 3.2.4
exists only as a source tag (`release_3_2_4`). The download site's
i8086-msdos cross compilers stop at 3.2.2, so trying 3.2.4 (or `main`)
would mean building an i8086 cross compiler and its msdos RTL from
source.

The changes from 3.2.2 to 3.2.4 (2,378 commits) include
`compiler/i8086/cgcpu.pas`, `compiler/i8086/n8086mat.pas` and
`packages/fv/src/editors.pas`. None of the commit messages describes the
pointer-difference bug in patch 1, so whether 3.2.4 fixes it is unknown.
To find out with a newer compiler, compile

```pascal
function D (p, q : PChar) : Word; begin D := p - q; end;
```

with `-Wmlarge -al` and check that only 16 bits are stored into the
result. 3.2.4 does fix the keyboard driver's shift state (above), so with
it the keyboard wrapper in `edsys.pas` would be unnecessary, though
harmless.

Until a release is shown to fix it, patch 1 is needed. Patches 2 to 6
change FreeVision itself, not code generation, and are needed with any
compiler.
