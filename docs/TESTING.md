# Testing

## Automatic

`make test` runs `tests/run.sh`, about 200 checks, under DOSBox-X as
an 8086. Each step starts the editor with `--test-keys=KN.TXT`, which
types the keys in KN.TXT into the BIOS keyboard buffer one at a time,
holding the BIOS shift flags down for Shift, Ctrl and Alt. The keys
then go through INT 16h, FPC's keyboard driver and FreeVision as typed
keys do. The `dump` token writes the screen to KN.S1, KN.S2 and so on.
The host checks the files saved, the exit status, the standard output,
the screen dumps and, for Print, what reached LPT1. Most steps run on a
VGA. Steps 60 to 62 run on a CGA, a Hercules card, and a VGA with `/H`.

Each row of [COMPAT.md](COMPAT.md) names the step that tests it.

`make perf` measures the size, memory and speed on an emulated XT (see
the README).

## Manual: real hardware

DOSBox-X does not reproduce everything an XT does: the exact BIOS, the
83-key keyboard, CGA snow, MDA timing, a slow floppy, or a mouse driver.
Before a release that changes the keyboard, video or memory handling,
run these on real machines. Note the machine (CPU, BIOS, video, DOS
version, memory) with the result.

Suggested machines: an 8088 or V20 PC/XT with a CGA or MDA and an
83-key keyboard, such as a NuXT or an IBM 5150/5160; a 286 or later with
a 101-key keyboard and an EGA or VGA.

| # | Do | Expect |
|---|---|---|
| M1 | `EDIT` on a CGA, then File Exit | the menu bar, an empty UNTITLED1 window and the status line `<F1=Help> Press ALT to activate menus`. After exit, the DOS prompt on a clean 80x25 screen. |
| M2 | M1 on an MDA or Hercules card | the same in monochrome, readable, with the cursor visible. The screen is not blank, and there is no snow from a CGA mode being set. |
| M3 | M1 on an EGA and on a VGA, with `/H` | 43 rows on the EGA and 50 on the VGA. After exit, 25 rows again. |
| M4 | On a 40-column CGA mode (`MODE CO40`), `EDIT` | it switches to 80 columns |
| M5 | `EDIT README.TXT`, then hold Down to the end and back | it scrolls steadily, with no stray characters or snow beyond what the CGA always shows |
| M6 | On an 83/84-key keyboard: Shift+Right, Shift+Down, Shift+End, with Num Lock off | text is selected, not digits typed. With Num Lock on, Shift+keypad moves without selecting (the BIOS's behaviour). |
| M7 | Shift+Del, Ctrl+Ins, Shift+Ins on an 83-key keyboard | cut, copy and paste work. If Ctrl+Ins does nothing, note the BIOS; Edit Copy always works. |
| M8 | Ctrl+W, Ctrl+Z (XT) and Ctrl+Up, Ctrl+Down (101-key keyboard) | the window scrolls a line without moving the text |
| M9 | Alt pressed and released alone, then Alt+F, then F10 | each opens the menus. Holding Alt and typing a letter opens that menu and does not leave the bar active afterwards. |
| M10 | Ctrl+Break and Ctrl+C while editing | nothing happens: no `^C`, the editor keeps running |
| M11 | File Open on `A:` with no disk in the drive | a message box. Not "Abort, Retry, Fail?", and not a hang. |
| M12 | File Save to a write-protected floppy | a message box. The file stays open and modified. |
| M13 | File Print with the printer off or not connected, then on | a message box when it is off. With it on, the text prints, with a form feed at the end. |
| M14 | Open a 60 KB file from a floppy, then Ctrl+End, Ctrl+Home, Search Find a word near the end | each works. Note the times (compare with `make perf`). |
| M15 | Open 9 files, then File New | a message: no more than 9 files |
| M16 | Start EDIT with about 300 KB free (load TSRs, or use a 384 KB machine) | it starts, and Help About shows the free memory. With less, `edit: not enough memory`, exit status 8. |
| M17 | With a mouse driver loaded: click in the text, drag to select, click a menu | they work, and the mouse pointer is not left behind on the screen |
| M18 | `EDIT /B` on a colour adapter with a monochrome monitor | readable black and white |
| M19 | `EDIT /R CONFIG.SYS`, type, Del, Ctrl+Y | nothing changes, and File Save is refused |
| M20 | Under DOS 2.x or 3.0 (if available) | it starts and saves. A critical error may still show DOS's own prompt there, since DOS before 3.1 cannot fail a call from INT 24h. |

Record the results in the pull request that prepares a release.
