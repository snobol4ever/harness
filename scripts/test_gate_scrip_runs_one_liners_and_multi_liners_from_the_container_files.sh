#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_scrip_runs_one_liners_and_multi_liners_from_the_container_files.sh -- CIO-32 with CIO-34 (GOAL-CIO.md), row
# scrip-run-one-liners-and-run-multi-liners-read-the-container-files-and-run-each-test-anew, officer_01 2026-11-10. SCRIP reads a format-2
# container itself (ALL.csv by column name, ONE-LINERS.EXT line for line, MULTI-LINERS.md sections of fences: language, args, stdin, stdout, stderr) and runs
# each test anew in a fork with its stdin and args, writing OUT/NAME.out and OUT/NAME.err and one report line a test: name, result type, number,
# wall s, cpu s, peak KB. It compares nothing. The format bytes are the ones agreed with officer_04 (both LEDGERs, 2026-11-10 09:1x CST).
# This gate builds a scratch container in that format and reads: every result type (EXIT with its status, ABORT, CRASH, TIMEOUT, HANG,
# OVERFLOW, REFUSED, DEFERRED); a test with stdin (whose text holds a heading-like line) and one with args (one holding a space); stdout and
# stderr apart; a program in a four-backtick fence holding a three-backtick line; a staged test holding a file fence (CIO-55), its companion written beside the program and the test RUN (run-switches step 1, CTO-575), and a staged test with neither a file fence nor a stage name read as DEFERRED; a global set by one test unset in the next; the report in
# index order; --only; --compile writing assembly and running nothing; and the refusals (rc 2, no test run) for a ONE line count off the
# index, a heading the index lacks, an unclosed fence and an --only name the group lacks. rc 0 GREEN, 1 RED (named), 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
G=test_gate_scrip_runs_one_liners_and_multi_liners_from_the_container_files
TREE="$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null)"
[ -x "$SCRIP" ] || { echo "REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
mkdir -p "/tmp/s4e/${S4E_SEAT:-gate}" 2>/dev/null
T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-gate}/runliners.XXXXXX" 2>/dev/null || mktemp -d)" || { echo "REFUSE(2) [$G]: no scratch dir"; exit 2; }
trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
printf "        OUTPUT = 'hello'\nEND\n" > hello.sno
[ "$(timeout -k 5 30 "$SCRIP" --run hello.sno < /dev/null 2>/dev/null)" = hello ] || { echo "REFUSE(2) [$G]: scrip --run hello.sno does not print hello -- scrip itself is broken here"; exit 2; }
C="$T/c"
mkdir -p "$C"
LONG="$(printf 'L%.0s' $(seq 1 300))"
cat > "$C/ALL.csv" <<EOF
entry,group,road,nonl,timeout_s,heap_kb,stack_kb,compile_args,run_args,note
one_hello,one,direct,,,,,,,
one_setx,one,,,,131072,4096,,,"a cell, with a comma and a ""quote"""
one_seex,one,,,,,,,,
m_exit3,multi,direct,,,131072,4096,,,
m_abort,multi,,,,,,,,
m_segv,multi,,,,,,,,
m_busy,multi,,,2,,,,,
m_block,multi,,,2,,,,,
m_flood,multi,,,,,,,,
m_staged,multi,staged,,,,,,,
m_bare,multi,staged,,,,,,,
m_stdin,multi,,,,,,,,
m_args,multi,,,,,,,,
m_streams,multi,,,,,,,,
m_fence4,multi,,,,,,,,
$LONG,multi,,,,,,,,
EOF
cat > "$C/ONE-LINERS.sno" <<'EOF'
 OUTPUT = 'hello';END;* one_hello
 X = 'set'; OUTPUT = X;END;* one_setx
 OUTPUT = IDENT(X) 'unset';END;* one_seex
EOF
printf 'hello\nset\nunset\n' > "$C/ONE.stdout"
{
cat <<'EOF'
## m_exit3

An exit status: the description line is never read.

```SNOBOL4
        OUTPUT = 'three'
        &CODE = 3
END
```

```stdout
three
```

## m_abort

```SNOBOL4
        HOST(1, 'kill -ABRT $PPID')
        OUTPUT = 'not reached'
END
```

## m_segv

```SNOBOL4
        HOST(1, 'kill -SEGV $PPID')
        OUTPUT = 'not reached'
END
```

## m_busy

```SNOBOL4
LOOP    :(LOOP)
END
```

## m_block

```SNOBOL4
        HOST(1, 'sleep 60')
END
```

## m_flood

```SNOBOL4
        X = DUPL('x', 1000)
LOOP    OUTPUT = X :(LOOP)
END
```

## m_staged

```SNOBOL4
        INPUT(.F, 5, 'm_staged.dat') :F(NO)
        OUTPUT = F :(END)
NO      OUTPUT = 'the companion file is not beside the program'
END
```

```file m_staged.dat
a companion file of a staged test (CIO-55)
```

## m_bare

```SNOBOL4
        OUTPUT = 'a staged test with no file fence and no stage name is not run'
END
```

## m_stdin

```SNOBOL4
LOOP    OUTPUT = INPUT :S(LOOP)
END
```

```stdin
## not a heading
second
```

```stdout
## not a heading
second
```

## m_args

```SNOBOL4
        OUTPUT = HOST(0)
END
```

```args
one two
three
```

## m_streams

```SNOBOL4
        OUTPUT = 'to out'
        TERMINAL = 'to err'
END
```

```stdout
to out
```

```stderr
to err
```

## m_fence4

````SNOBOL4
* ```
        OUTPUT = 'fence'
END
````

EOF
printf '## %s\n\n```SNOBOL4\n        OUTPUT = %s\nEND\n```\n\n' "$LONG" "'long'"
} > "$C/MULTI-LINERS.md"
reds=""
red() { reds="$reds $1"; echo "  RED $1"; }
field() { awk -F'\t' -v n="$2" -v k="$3" '$1 == n { print $k; exit }' "$1"; }
want() {
  local rep="$1" n="$2" ty="$3" num="${4:-}" got gnum
  got="$(field "$rep" "$n" 2)"
  gnum="$(field "$rep" "$n" 3)"
  [ "$got" = "$ty" ] || { red "$n:type=${got:-none}:want=$ty"; return; }
  [ -z "$num" ] || [ "$gnum" = "$num" ] || red "$n:number=$gnum:want=$num"
}
printf '%s\n' one_hello one_setx one_seex > only1.txt
grep -v "^$LONG" <<EOF > onlym.txt
m_exit3
m_abort
m_segv
m_busy
m_block
m_flood
m_staged
m_bare
m_stdin
m_args
m_streams
m_fence4
EOF
timeout -k 5 120 "$SCRIP" --run-one-liners "$C" --out "$T/o1" > rep1.tsv 2> err1.txt < /dev/null
rc1=$?
S4E_OUTPUT_CAP_MB=1 timeout -k 5 120 "$SCRIP" --run-multi-liners "$C" --out "$T/om" --only onlym.txt --work "$T/w" > repm.tsv 2> errm.txt < /dev/null
rcm=$?
printf '%s\n' "$LONG" > onlylong.txt
timeout -k 5 60 "$SCRIP" --run-multi-liners "$C" --out "$T/ol" --only onlylong.txt > repl.tsv 2> errl.txt < /dev/null
rcl=$?
cat rep1.tsv repm.tsv
[ "$rc1" = 0 ] || red "run-one-liners:rc=$rc1:want=0"
[ "$rcm" = 0 ] || red "run-multi-liners:rc=$rcm:want=0"
[ "$(cut -f1 rep1.tsv | tr '\n' ' ')" = "one_hello one_setx one_seex " ] || red "one:report-order"
[ "$(cut -f1 repm.tsv | tr '\n' ' ')" = "$(tr '\n' ' ' < onlym.txt)" ] || red "multi:report-order"
awk -F'\t' 'NF != 6 { bad = 1 } END { exit bad }' rep1.tsv repm.tsv || red "report:six-tab-separated-fields"
want rep1.tsv one_hello EXIT 0
want rep1.tsv one_setx EXIT 0
want rep1.tsv one_seex EXIT 0
[ "$(cat "$T/o1/one_hello.out" 2>/dev/null)" = hello ] || red "one_hello:stdout"
[ "$(cat "$T/o1/one_seex.out" 2>/dev/null)" = unset ] || red "one_seex:a-global-of-one_setx-reached-the-next-test"
want repm.tsv m_exit3 EXIT 3
[ "$(cat "$T/om/m_exit3.out" 2>/dev/null)" = three ] || red "m_exit3:stdout"
want repm.tsv m_abort ABORT 6
want repm.tsv m_segv CRASH 11
want repm.tsv m_busy TIMEOUT 2
want repm.tsv m_block HANG 2
want repm.tsv m_flood OVERFLOW 25
want repm.tsv m_staged EXIT 0
[ "$(cat "$T/om/m_staged.out" 2>/dev/null)" = "a companion file of a staged test (CIO-55)" ] || red "m_staged:the-companion-file-was-not-read"
want repm.tsv m_bare DEFERRED 0
[ ! -e "$T/om/m_bare.out" ] || red "m_bare:was-run"
want repm.tsv m_stdin EXIT 0
[ "$(cat "$T/om/m_stdin.out" 2>/dev/null)" = "$(printf '## not a heading\nsecond')" ] || red "m_stdin:stdout"
want repm.tsv m_args EXIT 0
[ "$(cat "$T/om/m_args.out" 2>/dev/null)" = "one two three" ] || red "m_args:host0=$(cat "$T/om/m_args.out" 2>/dev/null)"
want repm.tsv m_streams EXIT 0
[ "$(cat "$T/om/m_streams.out" 2>/dev/null)" = "to out" ] || red "m_streams:stdout"
grep -qx "to err" "$T/om/m_streams.err" 2>/dev/null || red "m_streams:stderr-apart"
want repm.tsv m_fence4 EXIT 0
[ "$(cat "$T/om/m_fence4.out" 2>/dev/null)" = fence ] || red "m_fence4:stdout"
[ -z "$(ls -A "$T/w" 2>/dev/null)" ] || red "work:test-directories-left-behind"
[ "$rcl" = 2 ] || red "long-name:rc=$rcl:want=2"
[ "$(cut -f2 repl.tsv)" = REFUSED ] || red "long-name:type=$(cut -f2 repl.tsv):want=REFUSED"
timeout -k 5 60 "$SCRIP" --compile --run-one-liners "$C" --out "$T/oc" --only only1.txt > repc.tsv 2> errc.txt < /dev/null
rcc=$?
[ "$rcc" = 0 ] || red "compile:rc=$rcc:want=0"
want repc.tsv one_hello EXIT 0
grep -q "[a-z]" "$T/oc/one_hello.s" 2>/dev/null || red "compile:no-assembly-in-one_hello.s"
[ ! -e "$T/oc/one_hello.out" ] || red "compile:ran-the-program"
refusal() {
  local tag="$1"; shift
  "$@" > "$T/r.$tag.tsv" 2> "$T/r.$tag.err" < /dev/null
  local rc=$?
  [ "$rc" = 2 ] || red "refuse-$tag:rc=$rc:want=2"
  [ ! -s "$T/r.$tag.tsv" ] || red "refuse-$tag:a-test-ran-before-the-refusal"
}
mk() { rm -rf "$T/$1"; cp -r "$C" "$T/$1"; }
mk extra && echo " OUTPUT = 'extra';END;* extra" >> "$T/extra/ONE-LINERS.sno"
refusal one-line-count timeout -k 5 30 "$SCRIP" --run-one-liners "$T/extra" --out "$T/rx"
mk head && printf '## no_such_entry\n\n```SNOBOL4\nEND\n```\n' >> "$T/head/MULTI-LINERS.md"
refusal heading-the-index-lacks timeout -k 5 30 "$SCRIP" --run-multi-liners "$T/head" --out "$T/rh"
mk open && sed -i 's/^````$/```/' "$T/open/MULTI-LINERS.md"
refusal unclosed-fence timeout -k 5 30 "$SCRIP" --run-multi-liners "$T/open" --out "$T/ro"
echo m_no_such > nosuch.txt
refusal only-name-the-group-lacks timeout -k 5 30 "$SCRIP" --run-multi-liners "$C" --out "$T/rn" --only nosuch.txt
n=0
for r in $reds; do n=$((n + 1)); done
echo "SCRIP_RUN_LINERS_BOARD reds=$n tests=$(cat rep1.tsv repm.tsv | wc -l) (tree $TREE)"
[ "$n" = 0 ] && { echo "GATE OK [$G]: every result type, stdin, args, the two streams, the long fence, the file fence, fresh globals, --only, --compile and four refusals read as designed"; exit 0; }
echo "GATE FAIL [$G]: $n red:$reds"
exit 1
