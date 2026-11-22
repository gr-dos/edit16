# Compatibility with MS-DOS EDIT

edit16 follows the MS-DOS EDIT of MS-DOS 5 and 6: its menus, its keys
(the WordStar ones included) and its command line. It also has
multiple open files, as EDIT 2.0 (MS-DOS 7) does. This file lists what
matches, what differs and what is missing. "Test" names the step in
`tests/run.sh` that checks it, or `manual` for the cases in
[TESTING.md](TESTING.md).

Key: ✓ as in EDIT, ≈ works but differs (see the note), ✗ missing.

## Command line

| EDIT | edit16 | Test | Note |
|---|---|---|---|
| `EDIT file` | ✓ | 10, 11 | a file that does not exist is created when first saved |
| `EDIT file1 file2 ...` | ✓ | 32, 33 | EDIT 2.0's multiple files; up to 9 |
| `EDIT *.TXT` | ≈ | 46 | shows the Open dialog with that wildcard (EDIT 2.0 opens every match) |
| `/B` black and white | ✓ | manual (M18) | |
| `/H` most lines | ✓ | 62 | 43 on an EGA, 50 on a VGA; ignored on a CGA or MDA |
| `/R` read only | ✓ | 36 | EDIT 2.0 |
| `/G` fast CGA, `/NOHI`, `/S` | ≈ | 56 | accepted and ignored |
| `/?` | ✓ | 1–3 | also `--help`, `-h`, `-?` |
| `--version` | (gr-dos) | 4 | `edit (gr-dos edit16) 0.01` |
| `/nn` binary mode (EDIT 2.0) | ✗ | | |
| bad switch | ≈ | 5, 6 | message and exit status 1; EDIT ignores it |

## Menus

| Menu | Item | edit16 | Test | Note |
|---|---|---|---|---|
| File | New | ✓ | 35 | opens another window (EDIT 5 replaces the file) |
| File | Open... | ✓ | 34, 51 | the dialog has no drive list: type a path with a wildcard, such as `A:\*.*`, in the name |
| File | Save | ✓ | 10, 13 | asks for a name for an untitled file |
| File | Save As... | ✓ | 15, 16 | asks before overwriting |
| File | Close | ✓ | 33 | EDIT 2.0; also Ctrl+F4 |
| File | Print... | ✓ | 53 | to PRN: the selected text or the whole file, CR LF and a form feed |
| File | Exit | ✓ | 12–14 | asks about each unsaved file |
| Edit | Cut, Copy, Paste, Clear | ✓ | 18–22 | only with a selection (Paste: with something to paste) |
| Search | Find... | ✓ | 23–27, 40 | Match Upper/Lowercase, Whole Word; starts with the word at the cursor |
| Search | Repeat Last Find | ✓ | 23, 25, 28 | F3, Ctrl+L |
| Search | Change... | ✓ | 29–31 | Find and Verify, Change All |
| View | Split Windows, Full Windows | ≈ | 35 | EDIT 2.0's Split shows one file twice; here it tiles the open files |
| View | file list, Next, Previous | ✓ | 32, 34, 35 | EDIT 2.0; F6, Shift+F6, Alt+1 to Alt+9 |
| View | Size Window (EDIT 2.0) | ✗ | | |
| Options | Display... | ≈ | 48, 55 | Tab Stops and Scroll Bars; no colour choices |
| Options | Help Path... | ✗ | | there is no QBASIC help file |
| Help | Getting Started, Keyboard | ≈ | 43 | short built-in texts, not EDIT's hyperlinked help |
| Help | About... | ✓ | 40, 43 | also shows the free memory |

The Help menu is next to Options, not at the right end of the menu bar.

## Keys

Every key in EDIT's Keyboard help, and the WordStar keys, are mapped.

| Action | Keys | edit16 | Test |
|---|---|---|---|
| move | arrows, Home, End, PgUp, PgDn, Ctrl+Left/Right, Ctrl+Home/End | ✓ | 17, 55 |
| next line | Ctrl+Enter, Ctrl+J | ✓ | 17 |
| top/bottom of window | Ctrl+Q E, Ctrl+Q X | ✓ | 17 |
| scroll a line | Ctrl+Up/Down, Ctrl+W/Z | ✓ | 55 |
| scroll a window sideways | Ctrl+PgUp/PgDn | ✓ | 55 |
| WordStar moves | Ctrl+E X S D A F R C, Ctrl+Q S D R C | ✓ | 17, 49, 55 |
| select | Shift with any move | ✓ | 18–20, 45 |
| insert/overtype | Ins, Ctrl+V | ✓ | 52, 55 |
| delete | Del, Ctrl+G, Bksp, Ctrl+H, Ctrl+T (word) | ✓ | 52, 55 |
| cut line, to end of line | Ctrl+Y, Ctrl+Q Y | ✓ | 21, 52 |
| insert line | Ctrl+N | ✓ | 52 |
| control character | Ctrl+P then the key | ✓ | 44 |
| indent, unindent | Tab, Shift+Tab, on selected lines | ✓ | 45, 48 |
| clipboard | Shift+Del, Ctrl+Ins, Shift+Ins | ✓ | 18–21, 47 |
| bookmarks | Ctrl+K 0–3, Ctrl+Q 0–3 | ✓ | 50 |
| find, change | Ctrl+Q F, Ctrl+Q A, F3, Ctrl+L | ✓ | 23, 28, 56 |
| menus | Alt alone, Alt+letter, F10 | ✓ | 42, 55 |
| help | F1, also in dialog boxes | ✓ | 43, 56 |
| WordStar block keys | Ctrl+K B, K, C, V ... | ✗ | |
| Ctrl+B, Ctrl+O, Ctrl+U | ignored, as in EDIT | ✓ | 55 |

On an 83- or 84-key keyboard (PC, XT), Shift with a keypad key types a
digit in the BIOS. edit16 turns Shift+keypad back into selection when
Num Lock is off (test 47). That keyboard's BIOS has no codes for
Ctrl+Up and Ctrl+Down, so use Ctrl+W and Ctrl+Z there. Whether it
passes Ctrl+Ins on at all depends on the BIOS (manual test M7). Edit
Copy always works.

## Files

| | MS-DOS EDIT | edit16 |
|---|---|---|
| size | as much as memory allows (QBASIC's far heap) | 65,280 bytes a file (one FreeVision buffer) |
| files open | 1 (EDIT 5), 9 (EDIT 2.0) | 9, as memory allows |
| line length | 255 (EDIT 5) | 32,767 columns |
| tab characters | expanded to spaces on loading | kept; shown at every 8th column |
| line ends on loading | CR LF, LF | CR LF, LF, CR, kept as they are |
| line end for Enter | CR LF | CR LF |
| Ctrl+Z at the end | kept | kept |
| backup (.BAK) | no | no |
| a file too big | not loaded | not loaded, with a message |

## Behaviour

| | MS-DOS EDIT | edit16 |
|---|---|---|
| cursor past the end of a line | yes | no: it stops at the end |
| welcome screen | yes, with Esc to skip it | no |
| settings saved (QBASIC.INI, EDIT.INI) | yes | no |
| colours | Options Display | fixed: EDIT's defaults, or /B |
| mouse | used if present | used if present (FreeVision); never needed |
| Find wraps round | yes | yes |
| read-only file (DOS attribute) | opens, fails on save | opens, fails on save with a message (test 57) |
| Ctrl+C, Ctrl+Break | ignored | ignored |
| disk errors | message box | message box (no "Abort, Retry, Fail?") |
| not enough memory | "Out of memory" | message and exit status 8 |

## Hardware

edit16 runs on an 8088 with a CGA, MDA (Hercules), EGA or VGA, in
80-column text mode (it switches from 40). It needs 300 KB of free
memory plus the size of the open files. It uses no instructions newer
than the 8086's: the test suite runs it on DOSBox-X's 8086 CPU. See
[TESTING.md](TESTING.md) for what has to be checked on real hardware.
