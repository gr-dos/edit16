#!/bin/sh
#
# Measure edit.exe on an emulated 4.77 MHz PC/XT: DOSBox-X with an 8086
# CPU (cputype=8086, core=normal) at a fixed 300 cycles, about an 8088
# at 4.77 MHz, and a CGA.  Prints the EXE's size, the memory free with
# an empty file and with a 60 KB one (Help About), and how long common
# operations take, in BIOS timer ticks (18.2 a second) and seconds.
#
# The times come from the test mode's "ticks" token (edtest.pas), which
# records the BIOS timer each time the editor is idle.  A time includes
# the redrawing the operation causes and one pass of the editor's idle
# loop; the emulation is not cycle exact, so compare the numbers with
# each other more than with a real XT.
#
# Usage: tests/perf.sh [path/to/edit.exe]
# Environment: DOSBOX (default dosbox-x), CYCLES (default 300).

set -u

top=$(cd "$(dirname "$0")/.." && pwd)
exe=${1:-$top/edit.exe}
DOSBOX=${DOSBOX:-dosbox-x}
CYCLES=${CYCLES:-300}

command -v "$DOSBOX" >/dev/null || { echo "$DOSBOX not found" >&2; exit 2; }
[ -f "$exe" ] || { echo "$exe not found" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/dosperf.XXXXXX")
trap 'rm -rf "$work"' EXIT
LC_ALL=C
export LC_ALL
cd "$work"
cp "$exe" EDIT.EXE

printf 'hello world\r\n' > small.txt
awk 'BEGIN { for (i = 1; i <= 2399; i++) printf "big line %05d xxxxxxxx\r\n", i
             printf "THE END\r\n" }' > big.txt
awk 'BEGIN { for (i = 0; i < 20; i++)
               printf "line %d with some text in it to move along nicely\r\n", i }' > med.txt

# ks: start up, then the About box
printf 'ticks Alt+H A dump Enter Alt+F X\n' > ks.txt
# kb: a 60 KB file: start up, page down, end, find near the end, find
# with no match, the About box
printf '%s\n' 'ticks PgDn ticks Ctrl+End ticks Ctrl+Home ticks' \
    'Alt+S F "THE END" Enter ticks Ctrl+Home ticks Alt+S F "zzz" Enter ticks' \
    'Enter Alt+H A dump Enter Alt+F X' > kb.txt
# km: 50 cursor moves, 30 lines down, 30 characters typed, the Find
# dialog opened and closed, a new window, a window switch
{
    printf 'ticks '
    i=0; while [ $i -lt 50 ]; do printf 'Right '; i=$((i + 1)); done
    printf 'ticks '
    i=0; while [ $i -lt 30 ]; do printf 'Down '; i=$((i + 1)); done
    printf 'ticks "abcdefghijabcdefghijabcdefghij" ticks Alt+S F ticks Esc ticks '
    printf 'Alt+F N ticks F6 ticks Alt+F X N N\n'
} > km.txt
printf '@echo off\nedit --test-keys=ks.txt small.txt\nedit --test-keys=kb.txt big.txt\nedit --test-keys=km.txt med.txt\n' > perf.bat

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 1800 \
    "$DOSBOX" -defaultconf -silent -nogui -nomenu \
    -set "dosbox machine=cga" \
    -set "cpu cputype=8086" -set "cpu core=normal" \
    -set "cpu cycles=fixed $CYCLES" \
    -c "mount c \"$work\"" -c "c:" -c "perf.bat" -c "exit" > dosbox.log 2>&1

# t FILE N: the Nth "ticks" value of FILE
t() { tr -d '\r' < "$1" 2>/dev/null | sed -n "$2p"; }
# row LABEL FILE A B [N]: the time from tick A to tick B, per N if given
row() {
    a=$(t "$2" "$3"); b=$(t "$2" "$4")
    if [ -z "$a" ] || [ -z "$b" ]; then
        printf '%-34s %s\n' "$1" '(missing)'
        return
    fi
    awk -v l="$1" -v a="$a" -v b="$b" -v n="${5:-1}" 'BEGIN {
        d = (b - a) / n
        printf "%-34s %6.1f ticks %6.2f s\n", l, d, d / 18.2 }'
}
free() {
    tr -d '\r' < "$1" 2>/dev/null | grep -ao '[0-9]* KB of memory free' |
        head -1 | sed 's/ of memory free//'
}

echo "edit.exe: $(wc -c < EDIT.EXE | tr -d ' ') bytes"
echo "memory free, empty file:  $(free KS.S1)"
echo "memory free, 60 KB file:  $(free KB.S1)"
echo "at $CYCLES cycles (about a 4.77 MHz 8088), CGA:"
awk -v a="$(t KS.T 1)" 'BEGIN { printf "%-34s %6.1f ticks %6.2f s\n", "start, empty file", a, a / 18.2 }'
awk -v a="$(t KB.T 1)" 'BEGIN { printf "%-34s %6.1f ticks %6.2f s\n", "start, 60 KB file", a, a / 18.2 }'
row 'cursor right (each)'       KM.T 1 2 50
row 'line down (each)'          KM.T 2 3 30
row 'character typed (each)'    KM.T 3 4 30
row 'Search menu, Find dialog'   KM.T 4 5
row 'close it (Esc)'            KM.T 5 6
row 'File New'                  KM.T 6 7
row 'next window (F6)'          KM.T 7 8
row 'page down, 60 KB file'     KB.T 1 2
row 'Ctrl+End, 60 KB file'      KB.T 2 3
row 'Ctrl+Home, 60 KB file'     KB.T 3 4
row 'Find at the end, 60 KB'    KB.T 4 5
row 'Find with no match, 60 KB' KB.T 6 7
