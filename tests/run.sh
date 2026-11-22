#!/bin/sh
#
# Test edit.exe under DOSBox-X emulating an 8086 (cputype=8086,
# core=normal), so an instruction from a later CPU is an illegal opcode.
#
# The editor is driven by its hidden test mode: --test-keys=KN.TXT reads
# keystrokes from KN.TXT, and the token "dump" in it writes the screen
# to KN.S1, KN.S2, ... (see edtest.pas).  One batch file runs every
# DOS-side step, and the results are checked on the host afterwards.
# Step N records the exit status in RN.TXT (3 means the key script ran
# out, so the editor was still waiting for keys) and standard output in
# ON.TXT.  rc.bat uses goto rather than "if errorlevel N echo ... >file"
# because the DOSBox-X shell opens the redirection even when the test is
# false.
#
# Most steps run on DOSBox-X's default VGA; the last ones run again on
# a CGA and on a Hercules (MDA) card, and with /H for 50 lines.
#
# To add a test: write its keys with "keys N", add a step to steps.bat
# (command, then "call rc N"), and the matching checks below.
#
# Usage: tests/run.sh [path/to/edit.exe]
# Environment: DOSBOX (default dosbox-x), KEEP=1 to keep the work
#              directory.

set -u

top=$(cd "$(dirname "$0")/.." && pwd)
exe=${1:-$top/edit.exe}
DOSBOX=${DOSBOX:-dosbox-x}

command -v "$DOSBOX" >/dev/null || { echo "$DOSBOX not found" >&2; exit 2; }
[ -f "$exe" ] || { echo "$exe not found" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/dosedit.XXXXXX")
pass=0
fail=0
LC_ALL=C
export LC_ALL

# ------------------------------------------------------------------
# fixtures

cd "$work" || exit 2
cp "$exe" edit.exe

crlf() { sed 's/$/\r/'; }

printf 'hello world\r\nsecond line\r\n' > a.txt
for f in y c s1 s2 s3 ro ks xt; do cp a.txt $f.txt; done
i=1
while [ $i -le 100 ]; do printf 'line %03d\r\n' $i; i=$((i + 1)); done > lines.txt
for f in nav cy ind mk; do cp lines.txt $f.txt; done
printf 'cat concat Cat CAT cat\r\n' > words.txt
for f in w1 w2 w3 w4 w5 w6 w7 m1 m2 m3; do cp words.txt $f.txt; done
printf 'a\tb\r\n  trailing  \r\n' > tabs.txt
cp tabs.txt tabs2.txt
printf 'unix\nline\n' > lf.txt
printf 'hello world\r\n    indented\r\n' > misc.txt
printf 'hello\r\n' > rof.txt
awk 'BEGIN { for (i = 1; i <= 60; i++)
               printf "word1 word2 word3 word4 %02d\r\n", i }' > ws.txt
cp a.txt lp.txt
printf 'old\r\n' > exist.txt
# big.txt: 59,987 bytes ending in THE END; huge.txt: 70,000 bytes
awk 'BEGIN { for (i = 1; i <= 2399; i++) printf "big line %05d xxxxxxxx\r\n", i;
             printf "THE END\r\n" }' > big.txt
head -c 70000 /dev/zero | tr '\0' h > huge.txt
{ head -c 1500 /dev/zero | tr '\0' x; printf '\r\nend\r\n'; } > long.txt

# keys N: the key script KN.TXT, from standard input
keys() { cat > "K$1.TXT"; }

# rc.bat N: writes the last exit status (0 to 9) to RN.TXT
{
    printf '@echo off\n'
    for n in 9 8 7 6 5 4 3 2 1; do printf 'if errorlevel %d goto rc%d\n' $n $n; done
    for n in 0 1 2 3 4 5 6 7 8 9; do
        printf ':rc%d\necho rc%d >c:\\r%%1.txt\ngoto end\n' $n $n
    done
    printf ':end\n'
} > rc.bat

# --- editing and saving
keys 10 <<'EOS'
dump End "!" dump Alt+F S Alt+F X
EOS
keys 11 <<'EOS'
"abc" Enter "def" dump Alt+F S Alt+F X
EOS
keys 12 <<'EOS'
"xyz" Alt+F X dump N
EOS
keys 13 <<'EOS'
"Z" Alt+F X Y
EOS
keys 14 <<'EOS'
"Q" Alt+F X Esc dump Alt+F X N
EOS
keys 15 <<'EOS'
"saved" Alt+F A dump "SA.TXT" Enter dump Alt+F X
EOS
keys 16 <<'EOS'
"new" Alt+F A "EXIST.TXT" Enter dump Y Alt+F X
EOS
keys 17 <<'EOS'
Ctrl+End dump Ctrl+Home dump Down Down End dump Ctrl+Enter dump
PgDn dump Ctrl+Q E dump Ctrl+Q X dump Ctrl+Right Ctrl+Right dump
Ctrl+Left dump Ctrl+X Ctrl+X Ctrl+D dump Alt+F X
EOS
# --- selection and the clipboard
keys 18 <<'EOS'
Shift+Right Shift+Right Shift+Right Shift+Right Shift+Right dump
Shift+Del End Shift+Ins Alt+F S Alt+F X
EOS
keys 19 <<'EOS'
Shift+End Ctrl+Ins Down Home Shift+Ins Alt+F S Alt+F X
EOS
keys 20 <<'EOS'
Shift+Right Shift+Right Shift+Right Shift+Right Shift+Right "HI"
Down Home Shift+End Del Alt+F S Alt+F X
EOS
keys 21 <<'EOS'
Ctrl+Y Ctrl+Y Down Shift+Ins Alt+F S Alt+F X
EOS
keys 22 <<'EOS'
Alt+E dump Esc Shift+Right Alt+E dump Esc Alt+F X N
EOS
# --- find
keys 23 <<'EOS'
Ctrl+Q F dump Enter dump F3 "X" Alt+F S Alt+F X
EOS
keys 24 <<'EOS'
Alt+S F "Cat" Tab Space Enter "#" Alt+F S Alt+F X
EOS
keys 25 <<'EOS'
Alt+S F "cat" Tab Down Space Enter F3 "!" Alt+F S Alt+F X
EOS
keys 26 <<'EOS'
Alt+S F "zzz" Enter dump Enter Alt+F X
EOS
keys 27 <<'EOS'
Ctrl+End Alt+S F "concat" Enter "Y" Alt+F S Alt+F X
EOS
keys 28 <<'EOS'
Ctrl+L "cat" Enter Ctrl+L "@" Alt+F S Alt+F X
EOS
# --- change
keys 29 <<'EOS'
Alt+S C dump "cat" Tab "dog" Alt+C dump Enter Alt+F S Alt+F X
EOS
keys 30 <<'EOS'
Alt+S C "cat" Tab "dog" Enter dump C S C Esc Alt+F S Alt+F X
EOS
keys 31 <<'EOS'
Alt+S C "cat" Tab "Dog" Tab Space Alt+C Enter Alt+F S Alt+F X
EOS
# --- several files
keys 32 <<'EOS'
dump Alt+V dump Esc F6 dump "1" F6 "2" Alt+F X Y Y
EOS
keys 33 <<'EOS'
"X" Ctrl+F4 dump N dump Alt+F X
EOS
keys 34 <<'EOS'
Alt+F O dump "A.TXT" Enter dump Alt+1 dump Alt+F X
EOS
keys 35 <<'EOS'
Alt+F N Alt+F N dump Alt+V dump Esc Alt+1 dump Alt+V S dump Alt+V F dump Alt+F X
EOS
# --- read only, tabs, line ends, limits
keys 36 <<'EOS'
"junk" Del Ctrl+Y Enter dump Alt+F X
EOS
keys 37 <<'EOS'
End Tab "c" Down End " " Up dump Alt+F S Alt+F X
EOS
keys 38 <<'EOS'
End "!" Enter "new" Alt+F S Alt+F X
EOS
keys 39 <<'EOS'
dump Enter dump Alt+F X
EOS
keys 40 <<'EOS'
Ctrl+End dump Ctrl+Home Alt+S F "THE END" Enter "X" Alt+F S Alt+H A dump Enter Alt+F X
EOS
keys 41 <<'EOS'
End dump "!" Ctrl+Home dump Alt+F S Alt+F X
EOS
# --- menus, help, other keys
keys 42 <<'EOS'
Alt dump Enter dump Esc Esc Alt+F X
EOS
keys 43 <<'EOS'
F1 dump PgDn dump Esc Alt+H K dump Esc Alt+H A dump Enter Alt+F X
EOS
keys 44 <<'EOS'
Ctrl+P Ctrl+L "x" Alt+F A "LIT.TXT" Enter Alt+F X
EOS
keys 45 <<'EOS'
Shift+Down Shift+Down Tab dump Alt+F S Shift+Tab Alt+F A "IND2.TXT" Enter Alt+F X
EOS
keys 46 <<'EOS'
dump Esc Alt+F X
EOS
keys 47 <<'EOS'
Shift+#5230 Shift+#4D36 Shift+#4D36 Shift+#4D36 Shift+#4D36 Shift+#4D36
Shift+#5230 Ctrl+Ins End Shift+#5230
Down Home Shift+#4D36 Shift+#4D36 Shift+#532E Alt+F S Alt+F X
EOS
keys 48 <<'EOS'
Alt+O D dump Tab "4" Enter End Tab "c" Alt+F S Alt+F X
EOS
keys 49 <<'EOS'
Ctrl+Q C "E" Ctrl+Q R "S" Alt+F S Alt+F X
EOS
keys 50 <<'EOS'
Down Down Down Down Down Ctrl+K 1 Ctrl+Home Ctrl+Q 1 "B" Alt+F S Alt+F X
EOS
keys 51 <<'EOS'
dump Enter Alt+F X
EOS
keys 52 <<'EOS'
Ins "HE" Ins End Bksp Home Ctrl+T Ctrl+N "top" Down Down End Enter "auto"
Up Up Right Ctrl+Q Y dump Alt+F S Alt+F X
EOS
keys 55 <<'EOS'
Ctrl+X dump Ctrl+D dump Ctrl+F dump Ctrl+A dump Ctrl+D Ctrl+D Ctrl+S dump
Ctrl+E dump Ctrl+C dump Ctrl+R dump Ctrl+Z dump Ctrl+W dump
Ctrl+B Ctrl+O Ctrl+U dump Ctrl+PgDn dump Ctrl+PgUp dump
F10 Enter dump Esc Esc Alt+O D Space Enter dump Alt+O D Space Enter
Ctrl+Home Ctrl+V "AB" Ctrl+V Ctrl+G Ctrl+D Ctrl+H Alt+F S Alt+F X
EOS
keys 56 <<'EOS'
dump Ctrl+Q A dump Esc Alt+S F F1 dump Esc Esc Alt+F X
EOS
keys 57 <<'EOS'
dump End "!" Alt+F S dump Enter Alt+F X N
EOS
keys 53 <<'EOS'
Alt+F P dump Enter Down Shift+End Alt+F P Enter Alt+F X
EOS
# --- other video adapters (steps 60-62 run in their own DOSBox-X)
keys 60 <<'EOS'
End "!" dump Alt+H A dump Enter Alt+F S Alt+F X
EOS
cp K60.TXT K61.TXT
cp K60.TXT K62.TXT
for f in cga herc vgah; do cp a.txt $f.txt; done

cat > steps.bat <<'EOS'
@echo off
rem --- help, version, usage errors
edit --help >o1.txt
call rc 1
edit -h >o2.txt
call rc 2
edit /? >o3.txt
call rc 3
edit --version >o4.txt
call rc 4
edit /Z >o5.txt
call rc 5
edit --bogus >o6.txt
call rc 6
edit --test-keys=nokeys.txt >o7.txt
call rc 7
rem --- editing and saving
edit --test-keys=k10.txt a.txt >o10.txt
call rc 10
edit --test-keys=k11.txt n1.txt >o11.txt
call rc 11
edit --test-keys=k12.txt >o12.txt
call rc 12
edit --test-keys=k13.txt y.txt >o13.txt
call rc 13
edit --test-keys=k14.txt c.txt >o14.txt
call rc 14
edit --test-keys=k15.txt >o15.txt
call rc 15
edit --test-keys=k16.txt >o16.txt
call rc 16
edit --test-keys=k17.txt nav.txt >o17.txt
call rc 17
rem --- selection and the clipboard
edit --test-keys=k18.txt s1.txt >o18.txt
call rc 18
edit --test-keys=k19.txt s2.txt >o19.txt
call rc 19
edit --test-keys=k20.txt s3.txt >o20.txt
call rc 20
edit --test-keys=k21.txt cy.txt >o21.txt
call rc 21
edit --test-keys=k22.txt a.txt >o22.txt
call rc 22
rem --- find
edit --test-keys=k23.txt w1.txt >o23.txt
call rc 23
edit --test-keys=k24.txt w2.txt >o24.txt
call rc 24
edit --test-keys=k25.txt w3.txt >o25.txt
call rc 25
edit --test-keys=k26.txt words.txt >o26.txt
call rc 26
edit --test-keys=k27.txt w4.txt >o27.txt
call rc 27
edit --test-keys=k28.txt w5.txt >o28.txt
call rc 28
rem --- change
edit --test-keys=k29.txt w6.txt >o29.txt
call rc 29
edit --test-keys=k30.txt w7.txt >o30.txt
call rc 30
edit --test-keys=k31.txt m1.txt >o31.txt
call rc 31
rem --- several files
edit --test-keys=k32.txt m2.txt m3.txt >o32.txt
call rc 32
edit --test-keys=k33.txt a.txt words.txt >o33.txt
call rc 33
edit --test-keys=k34.txt >o34.txt
call rc 34
edit --test-keys=k35.txt >o35.txt
call rc 35
rem --- read only, tabs, line ends, limits
edit /R --test-keys=k36.txt ro.txt >o36.txt
call rc 36
edit --test-keys=k37.txt tabs.txt >o37.txt
call rc 37
edit --test-keys=k38.txt lf.txt >o38.txt
call rc 38
edit --test-keys=k39.txt huge.txt >o39.txt
call rc 39
edit --test-keys=k40.txt big.txt >o40.txt
call rc 40
edit --test-keys=k41.txt long.txt >o41.txt
call rc 41
rem --- menus, help, other keys
edit --test-keys=k42.txt a.txt >o42.txt
call rc 42
edit --test-keys=k43.txt >o43.txt
call rc 43
edit --test-keys=k44.txt >o44.txt
call rc 44
edit --test-keys=k45.txt ind.txt >o45.txt
call rc 45
edit --test-keys=k46.txt *.txt >o46.txt
call rc 46
edit --test-keys=k47.txt xt.txt >o47.txt
call rc 47
edit --test-keys=k48.txt tabs2.txt >o48.txt
call rc 48
edit --test-keys=k49.txt ks.txt >o49.txt
call rc 49
edit --test-keys=k50.txt mk.txt >o50.txt
call rc 50
edit --test-keys=k51.txt nodir\x.txt >o51.txt
call rc 51
edit --test-keys=k52.txt misc.txt >o52.txt
call rc 52
edit --test-keys=k53.txt lp.txt >o53.txt
call rc 53
loadfix -330 >nul
edit a.txt >o54.txt
call rc 54
loadfix -f >nul
edit --test-keys=k55.txt ws.txt >o55.txt
call rc 55
edit /G /NOHI /S --test-keys=k56.txt a.txt >o56.txt
call rc 56
attrib +r rof.txt >nul
edit --test-keys=k57.txt rof.txt >o57.txt
call rc 57
attrib -r rof.txt >nul
EOS

# dosbox MACHINE BATCH: run BATCH in a headless DOSBox-X; what is
# printed (LPT1) goes to LPT.OUT
dosbox() {
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 600 \
        "$DOSBOX" -defaultconf -silent -nogui -nomenu \
        -set "dosbox machine=$1" \
        -set "parallel parallel1=file file:$work/LPT.OUT" \
        -set "cpu cputype=8086" -set "cpu core=normal" -set "cpu cycles=max" \
        -c "mount c \"$work\"" -c "c:" \
        -c "$2" -c "exit" >>dosbox.log 2>&1
}

printf '@echo off\nedit --test-keys=k60.txt cga.txt >o60.txt\ncall rc 60\n' > cga.bat
printf '@echo off\nedit --test-keys=k61.txt herc.txt >o61.txt\ncall rc 61\n' > herc.bat
printf '@echo off\nedit /H --test-keys=k62.txt vgah.txt >o62.txt\ncall rc 62\n' > vgah.bat

dosbox svga_s3 steps.bat
dosbox cga cga.bat
dosbox hercules herc.bat
dosbox svga_s3 vgah.bat

# ------------------------------------------------------------------
# checks

ok()     { pass=$((pass + 1)); }
not_ok() { echo "FAIL: $*"; fail=$((fail + 1)); }

# check NAME COMMAND...
check() {
    name=$1
    shift
    if "$@"; then ok; else not_ok "$name"; fi
}

# rc STEP EXPECTED-STATUS
rc() {
    got=$(tr -d ' \r' < "R$1.TXT" 2>/dev/null | sed 's/^rc//')
    if [ "$got" = "$2" ]; then
        ok
    else
        not_ok "step $1: exit status ${got:-missing}, expected $2"
    fi
}

# expect STEP < expected-lines; compares ON.TXT with CRs removed
expect() {
    tr -d '\r' < "O$1.TXT" 2>/dev/null > got.txt
    cat > want.txt
    if cmp -s got.txt want.txt; then
        ok
    else
        not_ok "step $1: output differs"
        diff want.txt got.txt | sed 's/^/    /'
    fi
}

# file NAME < expected bytes (as printf would write them)
file() {
    name=$1
    want=$(cat)
    printf "$want" > want.bin
    got=$(ls | grep -ix "$name" | head -1)
    if [ -n "$got" ] && cmp -s want.bin "$got"; then
        ok
    else
        not_ok "file $name differs"
        { od -c want.bin | head -8; echo '    ---'; od -c "${got:-/dev/null}" | head -8; } | sed 's/^/    /'
    fi
}

# same NAME1 NAME2: two files are identical (DOS names in any case)
same() {
    a=$(ls | grep -ix "$1" | head -1)
    b=$(ls | grep -ix "$2" | head -1)
    if [ -n "$a" ] && [ -n "$b" ] && cmp -s "$a" "$b"; then
        ok
    else
        not_ok "$1 differs from $2"
    fi
}

# screen STEP N: dump N of step STEP, box characters as +, = and |
screen() {
    tr '\263\272\304\315\332\277\300\331\311\273\310\274\303\264\302\301\305\021\020\036\037\376\261\260\262' \
       '||==+++++++++++++<>^v#:::' < "K$1.S$2" 2>/dev/null | tr -d '\r'
}

# row STEP N ROW: row ROW (1 = top) of a dump without its last column
# (a window's scroll bar), trailing blanks removed
row() { screen "$1" "$2" | sed -n "$3p" | cut -c1-79 | sed 's/ *$//'; }

# shows STEP N TEXT: the dump has TEXT somewhere
shows() {
    if screen "$1" "$2" | grep -qF -- "$3"; then
        ok
    else
        not_ok "step $1 dump $2: no \"$3\""
        screen "$1" "$2" | sed 's/^/    | /'
    fi
}

# rowis STEP N ROW TEXT: row ROW is TEXT
rowis() {
    got=$(row "$1" "$2" "$3")
    if [ "$got" = "$4" ]; then
        ok
    else
        not_ok "step $1 dump $2 row $3: \"$got\", expected \"$4\""
    fi
}

# at STEP N LINE:COL: the status line shows the cursor at LINE:COL
at() { shows "$1" "$2" "| $3"; }

version=$(cat "$top/VERSION")

# help, version, usage errors
rc 1 0
check "step 1: usage" grep -q '^Usage: EDIT' O1.TXT
rc 2 0
check "step 2: -h same as --help" cmp -s O1.TXT O2.TXT
rc 3 0
check "step 3: /? same as --help" cmp -s O1.TXT O3.TXT
rc 4 0
expect 4 <<EOS
edit (gr-dos edit16) $version
EOS
rc 5 1
check "step 5: bad switch" grep -q 'invalid switch /Z' O5.TXT
rc 6 1
check "step 6: bad option" grep -q 'invalid option --bogus' O6.TXT
rc 7 2

# open, type, save, exit
rc 10 0
rowis 10 1 1 ' File  Edit  Search  View  Options  Help'
shows 10 1 ' A.TXT '
rowis 10 1 3 '|hello world'
at 10 1 00001:001
shows 10 1 'Press ALT to activate menus'
rowis 10 2 3 '|hello world!'
at 10 2 00001:013
file a.txt <<'EOS'
hello world!\r\nsecond line\r\n
EOS
# a file named on the command line that does not exist is new
rc 11 0
shows 11 1 ' N1.TXT '
file n1.txt <<'EOS'
abc\r\ndef
EOS
# exit asks about an untitled file; No discards it
rc 12 0
shows 12 1 'UNTITLED1 is not saved.'
shows 12 1 'Save it now?'
check "step 12: nothing saved" test ! -e UNTITLED1
# Yes saves
rc 13 0
file y.txt <<'EOS'
Zhello world\r\nsecond line\r\n
EOS
# Cancel stays in the editor
rc 14 0
rowis 14 1 3 '|Qhello world'
file c.txt <<'EOS'
hello world\r\nsecond line\r\n
EOS
# Save As
rc 15 0
shows 15 1 'Save As'
shows 15 1 'File Name'
shows 15 2 ' SA.TXT '
file sa.txt <<'EOS'
saved
EOS
rc 16 0
shows 16 1 'File already exists.'
file exist.txt <<'EOS'
new
EOS
# moving the cursor
rc 17 0
at 17 1 00101:001
at 17 2 00001:001
at 17 3 00003:009
at 17 4 00004:001
at 17 5 00024:001
at 17 6 00004:001
at 17 7 00024:001
at 17 8 00025:001
at 17 9 00024:006
at 17 10 00026:007

# selection and the clipboard
rc 18 0
at 18 1 00001:006
file s1.txt <<'EOS'
 worldhello\r\nsecond line\r\n
EOS
rc 19 0
file s2.txt <<'EOS'
hello world\r\nhello worldsecond line\r\n
EOS
rc 20 0
file s3.txt <<'EOS'
HI world\r\n\r\n
EOS
rc 21 0
check "step 21: Ctrl+Y cuts lines, Shift+Ins pastes the last" \
    sh -c 'head -3 cy.txt | tr -d "\r" | tr "\n" " " | grep -qx "line 003 line 002 line 004 "'
check "step 21: 99 lines" test "$(wc -l < cy.txt)" -eq 99
# Edit menu: Cut, Copy and Clear only with a selection
rc 22 0
shows 22 1 'Shift+Del'
shows 22 1 'Ctrl+Ins'
shows 22 1 'Shift+Ins'
shows 22 2 'Clear'

# find
rc 23 0
shows 23 1 'Find What'
shows 23 1 'Match Upper/Lowercase'
shows 23 1 'Whole Word'
shows 23 1 'Find What:   cat'
at 23 2 00001:004
file w1.txt <<'EOS'
cat conX Cat CAT cat\r\n
EOS
rc 24 0
file w2.txt <<'EOS'
cat concat # CAT cat\r\n
EOS
rc 25 0
file w3.txt <<'EOS'
cat concat ! CAT cat\r\n
EOS
rc 26 0
shows 26 1 'Match not found.'
rc 27 0
file w4.txt <<'EOS'
cat Y Cat CAT cat\r\n
EOS
rc 28 0
file w5.txt <<'EOS'
cat con@ Cat CAT cat\r\n
EOS

# change
rc 29 0
shows 29 1 'Change To'
shows 29 1 'Find and Verify'
shows 29 1 'Change All'
shows 29 2 'Change complete.'
file w6.txt <<'EOS'
dog condog dog dog dog\r\n
EOS
rc 30 0
shows 30 1 'Change this occurrence?'
file w7.txt <<'EOS'
dog concat dog CAT cat\r\n
EOS
rc 31 0
file m1.txt <<'EOS'
Dog conDog Cat CAT Dog\r\n
EOS

# several files
rc 32 0
shows 32 1 ' M3.TXT '
shows 32 2 '1 M2.TXT'
shows 32 2 '2 M3.TXT'
shows 32 2 'Split Windows'
shows 32 3 ' M2.TXT '
file m2.txt <<'EOS'
1cat concat Cat CAT cat\r\n
EOS
file m3.txt <<'EOS'
2cat concat Cat CAT cat\r\n
EOS
rc 33 0
shows 33 1 'WORDS.TXT is not saved.'
shows 33 2 ' A.TXT '
file words.txt <<'EOS'
cat concat Cat CAT cat\r\n
EOS
rc 34 0
shows 34 1 'Open'
shows 34 1 'A.TXT'
shows 34 2 ' A.TXT '
shows 34 3 ' UNTITLED1 '
rc 35 0
shows 35 1 ' UNTITLED3 '
shows 35 2 '3 UNTITLED3'
shows 35 3 ' UNTITLED1 '
shows 35 4 ' UNTITLED2 '
shows 35 4 ' UNTITLED3 '
check "step 35: full windows" test "$(screen 35 5 | grep -c UNTITLED)" -eq 1

# read only
rc 36 0
rowis 36 1 3 '|hello world'
file ro.txt <<'EOS'
hello world\r\nsecond line\r\n
EOS
# Tab inserts blanks to the next tab stop; tab characters and trailing
# blanks are kept
rc 37 0
rowis 37 1 3 '|a       b       c'
file tabs.txt <<'EOS'
a\tb       c\r\n  trailing   \r\n
EOS
# Enter makes CR LF; the file's own LF line ends stay
rc 38 0
file lf.txt <<'EOS'
unix!\r\nnew\nline\n
EOS
# a file over 65,280 bytes
rc 39 0
shows 39 1 'HUGE.TXT is too large'
shows 39 2 ' UNTITLED1 '
# a 60 KB file, and a match in its last bytes
rc 40 0
at 40 1 02401:001
check "step 40: last line changed" sh -c 'tail -c 3 big.txt | od -c | grep -q "X  *\\\\r  *\\\\n"'
check "step 40: rest unchanged" sh -c 'head -c 59970 big.txt | tail -c 20 | grep -q "02399"'
shows 40 2 'KB of memory free'
# a line longer than 1,024 characters
rc 41 0
at 41 1 00001:1501
rowis 41 2 3 "|$(head -c 78 /dev/zero | tr '\0' x)"
check "step 41: long line saved" \
    test "$(head -1 long.txt | tr -d '\r')" = "$(head -c 1500 /dev/zero | tr '\0' x)!"

# menus, help, other keys
rc 42 0
shows 42 1 'Commands for files'
shows 42 2 'Opens a new, untitled file'
rc 43 0
shows 43 1 'Getting Started'
shows 43 1 'Press and release Alt'
shows 43 3 'Keyboard'
shows 43 3 'Ctrl+Q S / Ctrl+Q D'
shows 43 4 "edit16 version $version"
rc 44 0
file lit.txt <<'EOS'
\fx
EOS
rc 45 0
shows 45 1 '        line 001'
head -2 lines.txt | sed 's/^/        /' > ind.want
tail -n +3 lines.txt >> ind.want
same ind.txt ind.want
same ind2.txt lines.txt
# a wildcard shows the Open dialog
rc 46 0
shows 46 1 'Open'
shows 46 1 '*.txt'
# on an 83-key keyboard Shift+keypad gives digits; Shift+Ins with an
# empty clipboard does nothing, even to a selection
rc 47 0
file xt.txt <<'EOS'
hello worldhello\r\ncond line\r\n
EOS
rc 48 0
shows 48 1 'Display'
shows 48 1 'Scroll Bars'
shows 48 1 'Tab Stops'
file tabs2.txt <<'EOS'
a\tb   c\r\n  trailing  \r\n
EOS
rc 49 0
file ks.txt <<'EOS'
Shello world\r\nsecond line\r\nE
EOS
rc 50 0
check "step 50: bookmark" sh -c 'sed -n 6p mk.txt | grep -q "^Bline 006"'
# a path that does not exist
rc 51 0
shows 51 1 'Path not found'

# Ctrl+T, Ctrl+N, Ins (overtype), Bksp, auto-indent, Ctrl+Q Y
rc 52 0
at 52 1 00003:001
file misc.txt <<'EOS'
top\r\nworl\r\n\r\n    auto\r\n
EOS
# Print: the whole file, then the selected text
rc 53 0
shows 53 1 'Selected Text Only'
shows 53 1 'Complete Document'
file LPT.OUT <<'EOS'
hello world\r\nsecond line\r\n\fsecond line\r\n\f
EOS

# the WordStar keys (the same positions as the arrows and PgUp/PgDn
# give), Ctrl+W/Z scrolling, Ctrl+B/O/U ignored, Ctrl+PgDn/PgUp, F10,
# Options Display Scroll Bars off, Ctrl+V overtype, Ctrl+G, Ctrl+H
rc 55 0
at 55 1 00002:001
at 55 2 00002:002
at 55 3 00002:007
at 55 4 00002:001
at 55 5 00002:002
at 55 6 00001:002
at 55 7 00021:002
at 55 8 00001:002
rowis 55 9 3 '|word1 word2 word3 word4 02'
at 55 9 00002:002
rowis 55 10 3 '|word1 word2 word3 word4 01'
at 55 11 00002:002
at 55 12 00002:027
at 55 13 00002:001
shows 55 14 'Open...'
check "step 55: scroll bars off" \
    test "$(screen 55 15 | sed -n 3p | cut -c80)" = '|'
check "step 55: Ctrl+V, Ctrl+G, Ctrl+H" \
    test "$(head -1 ws.txt | tr -d '\r')" = 'AB1 word2 word3 word4 01'

# EDIT's /G, /NOHI and /S are accepted; Ctrl+Q A; F1 in a dialog box
rc 56 0
shows 56 1 'A.TXT'
shows 56 2 'Change To:'
shows 56 3 'Getting Started'

# a file with the read-only attribute opens; saving it is refused
rc 57 0
shows 57 1 'hello'
shows 57 2 'Cannot save'
file rof.txt <<'EOS'
hello\r\n
EOS

# too little memory: a message, not a blank screen (LOADFIX holds 330 KB)
rc 54 8
check "step 54: not enough memory" grep -q 'not enough memory' O54.TXT

# other video adapters
for n in 60 61 62; do
    rc $n 0
    shows $n 1 '|hello world!'
    shows $n 2 'KB of memory free'
done
file cga.txt <<'EOS'
hello world!\r\nsecond line\r\n
EOS
file herc.txt <<'EOS'
hello world!\r\nsecond line\r\n
EOS
check "step 62: /H gives 50 rows" test "$(wc -l < K62.S1)" -eq 50

# ------------------------------------------------------------------

echo "$pass passed, $fail failed"
if [ "$fail" -ne 0 ] || [ "${KEEP:-0}" = 1 ]; then
    echo "work directory: $work"
else
    rm -rf "$work"
fi
[ "$fail" -eq 0 ]
