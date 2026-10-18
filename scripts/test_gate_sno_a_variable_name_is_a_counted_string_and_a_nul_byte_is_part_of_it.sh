#!/usr/bin/env bash
# test_gate_sno_a_variable_name_is_a_counted_string_and_a_nul_byte_is_part_of_it.sh -- A NAME IS ITS BYTES AND ITS LENGTH
#
# MEASURED 2026-10-02 by the cto (row snobol4-a-variable-name-may-begin-with-a-nul-byte-the-namespace-must-key-counted-strings-not-c-strings,
# ceo CEO-1407): sbl -bf accepts a variable whose name holds a NUL byte -- $&ALPHABET, $(CHAR(0) 'X'), $('X' CHAR(0) 'Y') -- and
# SCRIP's namespace keyed C strings: bn_sno_name (the $ operator) asked NV_intern_name_n, which refused any name holding a NUL,
# then spelled the name as a C string, so a name BEGINNING with NUL read as the null name and failed the statement, and a NUL
# INSIDE a name was silently truncated -- $('X' CHAR(0) 'Y') read and wrote the variable X. SnoRungs' last red
# (size_indirect_keyword_replace_branch_1) pinned the first; nothing pinned the second, which this gate's witness does.
# THE CURE (src/runtime/core/core.c, src/runtime/by_name_dispatch.c): every namespace entry carries its length and whether it holds
# a NUL; a C-string lookup matches only a NUL-free entry, a counted lookup compares length and bytes, the rehash reads the stored
# length, and NV_PTR_n finds or creates a counted name, which $ hands on as the cell itself so the name is never spelled again.
# 2026-10-02 later (row snobol4-a-pattern-capture-into-a-nul-named-variable-aborts-..., ceo CEO-1412): a CAPTURE into such a
# name ('abc' 'b' . $Z with Z = CHAR(0) 'Q') aborted rc=134 in the runtime pattern compiler, because SNO$PBC/PCUR/PDEF spelled the
# target as a C string. A name holding a NUL, or beginning with byte 1, now has ONE key everywhere: byte 1 followed by the hex of
# its bytes (NV_nul_key), which no source identifier can spell and which escapes its own lead byte, so $, the namespace and the
# pattern builders reach one variable. Witness c.sno pins the captures (. $ and a stored pattern) and the escape's collision case.
# ARMS: (a) the witness against the live sbl -bf oracle in m3 and m4, at the default arena and under SCRIP_GC_STRESS=1 (which must
# report collections>0); (b) the comparison can say no: the witness with each NUL-bearing name replaced by its C-string truncation
# must differ from the oracle in both modes -- which is what the defect printed.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_clean_bin 2>/dev/null)"; [ -x "${SBL:-}" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'EOW'
        Z = CHAR(0) 'X'
        $Z = 'nulx'
        $('X' CHAR(0) 'Y') = 'xnuly'
        X = 'plainx'
        $(CHAR(0)) = 'justnul'
        OUTPUT = '1 ' $Z
        OUTPUT = '2 ' $('X' CHAR(0) 'Y')
        OUTPUT = '3 ' X
        OUTPUT = '4 ' $(CHAR(0) 'X')
        OUTPUT = '5 ' $(CHAR(0))
        OUTPUT = '6 ' $('X')
        W = &ALPHABET
        $W = 'alpha'
        OUTPUT = '7 ' $&ALPHABET
        OUTPUT = '8 ' SIZE($Z) ' ' DIFFER($Z, $('X' CHAR(0) 'Y'))
        $Z = $Z '!'
        OUTPUT = '9 ' $(CHAR(0) 'X')
END
EOW
cat > "$T/c.sno" <<'EOW'
        Z = CHAR(0) 'Q'
        'abc' 'b' . $Z
        OUTPUT = '1 ' $Z
        'xyz' 'y' $ $Z
        OUTPUT = '2 ' $Z
        P = 'k' . $(CHAR(0) 'R')
        'mkn' P
        OUTPUT = '3 ' $(CHAR(0) 'R')
        W = CHAR(1) '0051'
        $W = 'one'
        'pqr' 'q' . $W
        OUTPUT = '4 ' $Z ' ' $W ' [' Q ']'
END
EOW
sed "s/\$('X' CHAR(0) 'Y')/\$('X')/g" "$T/w.sno" > "$T/t.sno"
cmp -s "$T/w.sno" "$T/t.sno" && { echo "⛔ GATE REFUSE(2) [$G]: the truncation plant changed nothing in the witness"; exit 2; }
want=$("$SBL" -bf "$T/w.sno" </dev/null 2>/dev/null); [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing"; exit 2; }
RC=0; N=0
run() {
  local m="$1" w="$2" st="$3" x="$T/$2.$1.$3"
  if [ "$m" = m3 ]; then env SCRIP_GC_STRESS="$st" SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$SCRIP" "$T/$w.sno" </dev/null >"$x.out" 2>"$x.err"
  else
    "$SCRIP" --compile -o "$x.s" "$T/$w.sno" </dev/null >/dev/null 2>&1 || { echo COMPILE-FAIL >"$x.out"; return; }
    gcc -no-pie -o "$x.bin" "$x.s" -L"$RT" -Wl,-rpath,"$RT" -lscrip_rt -lm >/dev/null 2>&1 || { echo LINK-FAIL >"$x.out"; return; }
    env SCRIP_GC_STRESS="$st" SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$x.bin" </dev/null >"$x.out" 2>"$x.err"
  fi
}
cwant=$("$SBL" -bf "$T/c.sno" </dev/null 2>/dev/null); [ -n "$cwant" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for c.sno"; exit 2; }
for st in 0 1; do
  for m in m3 m4; do
    N=$((N+1)); run $m c $st; got=$(grep -av '^\[GC-' "$T/c.$m.$st.out" | tr '\0' '@')
    if [ "$got" = "$cwant" ]; then echo "  (c) captures into NUL-bearing names, c.sno $m stress=$st vs oracle PASS"
    else echo "  (c) c.sno $m stress=$st vs oracle FAIL: got [$(printf '%s' "$got" | tr '\n' ' ' | cut -c1-140)] want [$(printf '%s' "$cwant" | tr '\n' ' ' | cut -c1-140)]"; RC=1; fi
  done
done
for st in 0 1; do
  for m in m3 m4; do
    N=$((N+1)); run $m w $st; x="$T/w.$m.$st"
    got=$(grep -av '^\[GC-' "$x.out" | tr '\0' '@'); col=$(cat "$x.out" "$x.err" | grep -ao 'collections=[0-9]*' | tail -1 | cut -d= -f2)
    if [ "$st" != 0 ] && [ "${col:-0}" -eq 0 ]; then echo "⛔ GATE REFUSE(2) [$G]: w $m under SCRIP_GC_STRESS=$st reported collections=${col:-none}"; exit 2; fi
    if [ "$got" = "$want" ]; then echo "  (a) w $m stress=$st collections=${col:-?} vs oracle PASS"
    else echo "  (a) w $m stress=$st vs oracle FAIL: got [$(printf '%s' "$got" | tr '\n' ' ' | cut -c1-140)] want [$(printf '%s' "$want" | tr '\n' ' ' | cut -c1-140)]"; RC=1; fi
  done
done
for m in m3 m4; do
  N=$((N+1)); run $m t 0; got=$(grep -av '^\[GC-' "$T/t.$m.0.out" | tr '\0' '@')
  if [ "$got" != "$want" ]; then echo "  (b) the truncated-name plant $m differs from the oracle PASS -- the comparison can say no"
  else echo "  (b) the truncated-name plant $m EQUALS the oracle FAIL -- the witness cannot tell a NUL name from its truncation"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N arms -- a name holding a NUL byte is its own variable in m3 and m4, across collections, and never its C-string truncation"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
exit $RC
