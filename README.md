# edit16

A full-screen text editor for 16-bit MS-DOS with the menus and keys of
MS-DOS EDIT, written in Free Pascal with FreeVision. It is distributed as
`EDIT.EXE` and invoked as `EDIT`.

It has EDIT's File, Edit, Search, Options and Help menus, its cursor,
selection and clipboard keys and the WordStar ones, Find and Change, and
Print. Like EDIT 2.0 (MS-DOS 7) it keeps up to nine files open, with a
View menu to switch between them or tile them. What matches EDIT and what
differs is in [`docs/COMPAT.md`](docs/COMPAT.md).

`edit.exe` is a large-model, real-mode 8086 executable for any DOS from
an original PC up, with a CGA, MDA (Hercules), EGA or VGA. It needs no
DPMI, XMS, EMS or mouse.

## Usage

    EDIT [/B] [/H] [/R] [[drive:][path]filename ...]

    filename   file(s) to edit, up to 9; one that does not exist is
               created when it is first saved; * or ? shows the Open dialog
    /B         black and white (a monochrome monitor on a colour adapter)
    /H         as many lines as the EGA or VGA shows (43 or 50)
    /R         read only: view the files without changing them
    /G /NOHI /S   accepted, as EDIT does, and ignored
    --help     show the usage and exit (also /?, -h, -?)
    --version  show the version and exit

Press and release Alt (or F10) for the menus, and F1 for help. Help
Keyboard lists every key. GR-DOS's `HELP EDIT` topic is
[`help/topics/EDIT.txt`](help/topics/EDIT.txt).

Exit status: 0 after File Exit, 1 for an unknown switch or option, 8 if
there is not enough memory to start. Messages go to standard output.

A file can be up to 65,280 bytes, and a line up to 32,767 columns. Files
are saved with CR LF line ends for new lines. A file's own line ends
(CR LF, LF or CR) and its tab characters are kept. Tabs show at every
8th column, and Options Display sets how far the Tab key indents.

## Size, memory and speed

Measured with `make perf`. That runs the editor under DOSBox-X as an 8086
at a fixed 300 cycles, about a 4.77 MHz 8088, with a CGA. The emulation
is not cycle-exact, so these are for comparing versions, not a promise
for a real XT.

| | 0.01 |
|---|---|
| `edit.exe` | 265 KB (268 KB in memory with its data and stack) |
| memory needed | 300 KB free, plus the size of the files open |
| free after starting, empty file | 320 KB (of 603 KB free in DOSBox-X) |
| free with a 60 KB file open | 264 KB |
| start, empty file / 60 KB file | 1.8 s / 3.5 s |
| cursor key, typed character | 0.17 s |
| Search menu and the Find dialog | 3.0 s |
| File New, F6 (next window) | 3.3 s, 1.8 s |
| Ctrl+End in a 60 KB file | 2.0 s |
| Find with no match in a 60 KB file (with the dialog) | 6.6 s |

Most of the time of a keystroke on an XT is now FreeVision's own drawing
(`TView.WriteView`'s clipping) and event routing. The rest of what was
slow has been fixed in edit16 or in its patched Editors unit. Both sets
of changes are listed in [`fv/README.md`](fv/README.md).

## Building

Everything is built and tested on a Linux host with GNU make and the
Free Pascal **i8086-msdos** cross-compiler, 3.2.2 (not the GO32v2/DPMI
target, and not a distribution `fpc` package, which lacks the i8086
target).

    make            # builds edit.exe
    make test       # runs the test suite under DOSBox-X (5 to 10 minutes)
    make perf       # size, memory and speed on an emulated XT
    make check-fv   # checks fv/editors.pas against the 3.2.2 release
    make dist       # build/edit16-VERSION.zip
    make clean

By default `make` runs `scripts/fetch-fpc8086`, as in less16. That
downloads the FPC 3.2.2 `x86_64-linux.cross.i8086-msdos` archive, checks
it against the SHA-256 in the script, and unpacks it into
`build/fpc8086`. This needs `curl`, `xz` and `sha256sum`. To use a copy
of the same release unpacked elsewhere:

    make FPC8086_ROOT=$HOME/opt/fpc/3.2.2

The flags are `-n -Tmsdos -Cp8086 -Wmlarge -O2 -Xs -XX -CX`, with only
the `8086-large` units. FreeVision's code does not fit in one 64 KB code
segment, so the small and compact models are out. The medium model
leaves about 16 KB of heap once a file is open, too little for several
files, so the large model is used.

FreeVision's Editors unit has bugs in the large model and on 16-bit
targets. One of them is a code-generation bug in FPC 3.2.2 that corrupts
the stack on the first draw. edit16 builds its own copy of the unit, the
3.2.2 file plus a patch, from [`fv/`](fv/). The provenance, the license,
each change and its reason, and what a newer compiler would change are
in [`fv/README.md`](fv/README.md). `make check-fv` (CI runs it) checks
that `fv/editors.pas` is exactly the 3.2.2 file with `fv/editors.diff`
applied.

## Conventions

This repository follows the [hello16](https://github.com/gr-dos/hello16)
conventions for gr-dos utilities, in less16's Free Pascal layout:

1. **Build and test on Linux** with GNU make, as above.
2. **`main` is protected:** it changes only by merging a pull request
   from a feature branch, with the `test` check from `ci.yml` required.
3. **Tests run under DOSBox-X** via `make test`. `tests/run.sh` needs
   `dosbox-x` (override with `DOSBOX=`; `KEEP=1` keeps the work
   directory). It runs DOSBox-X as an 8086 (`cputype=8086`,
   `core=normal`), so an instruction from a later CPU fails the suite.
   Most steps run on a VGA. The last ones run again on a CGA and a
   Hercules card, and with `/H`. The editor is driven by a hidden option,
   not shown in `--help`: `--test-keys=SCRIPT` types the keys in SCRIPT
   through the BIOS keyboard buffer, with the BIOS shift flags held for
   Shift, Ctrl and Alt. The token `dump` in SCRIPT writes the screen to a
   file. See `edtest.pas` for the script language and `tests/run.sh` for
   how steps are written. [`docs/TESTING.md`](docs/TESTING.md) has the
   manual tests for real hardware.
4. **CI must pass before merging:** `.github/workflows/ci.yml` builds,
   runs `make check-fv` and `make test`, and builds the archive, on every
   pull request and push to `main`.
5. **`--version` and `VERSION`:** `edit --version` prints
   `edit (gr-dos edit16) 0.01`, from the one line in `VERSION`. Versions
   are MS-DOS style: `0.01`, `0.02`, ... `1.00`.
6. **Releases:** `.github/workflows/release.yml` runs on every push to
   `main`. If `VERSION` has no `v<VERSION>` tag yet, it builds and tests,
   then tags and publishes a release with `edit.exe` and
   `edit16-VERSION.zip` attached. To release, bump `VERSION` in the PR.
7. **GR-DOS:** the release follows dist16's contract (gr-dos/gr-dos
   `docs/dist16.md`): an `edit.exe` asset, the 8.3 name `EDIT.EXE` (not
   one of GR-DOS's, since MS-DOS 4.00 has no EDIT), a real-mode MZ
   executable, and the MIT license. The zip carries the GR-DOS help topic
   at `help/topics/EDIT.txt`, the path gr-dos/gr-dos#90 proposes and
   cat16 uses, in GR-DOS's topic format (ASCII, lines of at most 79
   characters).

## Files

- `edit16.pas`: the program (command line, menus, files and windows,
  printing)
- `edview.pas`: the editor (`TEdEditor`: EDIT's keys, find and change,
  read only), its window, frame and status line
- `eddlg.pas`: the dialog boxes
- `edhelp.pas`: the Help menu's texts
- `edsys.pas`: machine-level fixes: video on CGA/MDA, the screen
  update, the keyboard's shift state, Ctrl+Break and critical errors
- `edtest.pas`: the test mode (`--test-keys`)
- `fv/`: FreeVision's Editors unit, patched, and its notices
  ([`fv/README.md`](fv/README.md))
- `help/topics/EDIT.txt`: the GR-DOS help topic
- `Makefile`: the build (`make`, `test`, `perf`, `check-fv`, `dist`,
  `clean`)
- `scripts/fetch-fpc8086`: fetch the pinned cross-compiler
- `scripts/check-fv`: check `fv/editors.pas` against the release
- `tests/run.sh`: the test suite, `make test`
- `tests/perf.sh`: the measurements, `make perf`
- `VERSION`: the version, compiled in and printed by `--version`
- `docs/COMPAT.md`: compatibility with MS-DOS EDIT
- `docs/TESTING.md`: manual tests, for real hardware
- `.github/workflows/ci.yml`, `release.yml`: CI and releases

## License

MIT, see `LICENSE`. The program is linked with Free Pascal's run-time
library and FreeVision, which are under the GNU Library GPL with the
Free Pascal linking exception (`fv/COPYING.FPC`, `fv/COPYING`; in the
release archive, `LICENSE.fv` and `COPYING.fv`). The source of the
modified FreeVision unit is `fv/`.
