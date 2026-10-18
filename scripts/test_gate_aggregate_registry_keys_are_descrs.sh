#!/usr/bin/env bash
# test_gate_aggregate_registry_keys_are_descrs.sh -- THE AGGREGATE REGISTRY IS KEYED BY THE DESCR ITSELF, NEVER BY A
# \001-TAGGED STRING (RULES.md FACT RULE NO DELIMITER-JOINED AGGREGATES; Lon 2026-09-28 to hq_pascal: "Are you storing data as
# tag delimited strings? ... Get rid of ALL delimited based processing like the one I just discovered."; the cfo's officer view
# adopted by the ceo at CEO-1350; row runtime-the-aggregate-registry-is-keyed-by-the-descr-itself-..., the cfo).
#
# WHAT WAS WRONG. src/runtime/aggregates.c already hashed and compared table keys by type and payload (_tbl_hkey, _tbl_eq_d),
# but the \001-tagged string form (tbl_key_str: "\001i123", "\001l<id>", "\001n" for the null key) survived in four places: a
# legacy hashing arm behind SCRIP_TBL_TYPED=0; tbl_pair_key(), which materialised TBPAIR_t.key = strdup(tagged) and was the
# value CONVERT(T,'ARRAY'), SORT(T) and COPY(T) handed a program for a NULL key -- so `T<> = 1; A = CONVERT(T,'ARRAY')` gave
# A<1,1> = "\001n", SIZE 2, where sbl -bf gives the null string (measured on c921c6dd5, both modes: arm 2's fail-once); the
# same-slot check of two table VCELLs in pattern_match.c, which compared the tagged strings; and SORT's same-rank tiebreak for
# non-string, non-numeric keys, which compared "\001l10" < "\001l9" lexicographically.
#
# WHAT HOLDS NOW. The DESCR is the key: tbl_key_equal (type word, then payload) decides identity, tbl_key_serial orders
# aggregate keys by their id numerically, bignums by rt_big_cmp; TBPAIR_t has no string key, no \001 is spelled in
# aggregates.c, and tbl_key_str / tbl_pair_key / SCRIP_TBL_TYPED do not exist. The delimited-aggregate census's REGISTRY_KEY
# row fell 9 -> 0 in the same landing.
#
# ARMS (the oracle is sbl -bf through lib_oracle_flags.sh; both modes):
#   1 THE COLLISION WITNESS: an integer key 5, the string key CHAR(1) "i5" (the tagged spelling of 5) and the string key "5"
#     are three entries and read back distinctly; SORT of a table with integer keys 10 and 9 and string keys orders 9 10 a b
#   2 THE NULL-KEY WITNESS: a null key through CONVERT(T,'ARRAY') and SORT(T) reads the null string, SIZE 0 (the fail-once:
#     "\001n", SIZE 2 on c921c6dd5)
#   3 THE AGGREGATE-KEY ORDER: twelve arrays as keys sort in creation order (l10 after l9), as sbl orders them
#   4 NO TAGGED SPELLING LEFT: no \001 in aggregates.c; no tbl_key_str, tbl_pair_key or SCRIP_TBL_TYPED anywhere under src/
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="${SPITBOL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL oracle at $SBL"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
w1() { cat > "$T/w1.sno" <<'EOF'
        T = TABLE()
        T[5] = "int five"
        T[CHAR(1) "i5"] = "string key"
        T["5"] = "string five"
        OUTPUT = T[5] " | " T[CHAR(1) "i5"] " | " T["5"]
        A = CONVERT(T, "ARRAY")
        OUTPUT = PROTOTYPE(A)
        T2 = TABLE()
        T2[10] = 1
        T2[9] = 1
        T2["b"] = 1
        T2["a"] = 1
        B = SORT(T2)
        OUTPUT = B[1,1] " " B[2,1] " " B[3,1] " " B[4,1]
END
EOF
}
w2() { cat > "$T/w2.sno" <<'EOF'
        T = TABLE()
        T[] = "null key"
        T["x"] = "x key"
        A = CONVERT(T, "ARRAY")
        OUTPUT = "[" A[1,1] "] size=" SIZE(A[1,1]) " val=" A[1,2]
        OUTPUT = "[" A[2,1] "] size=" SIZE(A[2,1]) " val=" A[2,2]
        B = SORT(T)
        OUTPUT = "[" B[1,1] "] size=" SIZE(B[1,1])
        C = COPY(T)
        D = CONVERT(C, "ARRAY")
        OUTPUT = "[" D[1,1] "] size=" SIZE(D[1,1])
END
EOF
}
w3() { cat > "$T/w3.sno" <<'EOF'
        T = TABLE()
        K = ARRAY(12)
        I = 1
L1      K[I] = ARRAY(1)
        T[K[I]] = I
        I = LT(I, 12) I + 1              :S(L1)
        B = SORT(T)
        I = 1
L2      OUT = OUT B[I,2] " "
        I = LT(I, 12) I + 1              :S(L2)
        OUTPUT = OUT
END
EOF
}
run_both() { local w="$1" tag="$2"
  ( cd "$T" && timeout -k 5 30s "$SBL" -bf "$w.sno" < /dev/null > "$tag.ref" 2>/dev/null )
  ( cd "$T" && timeout -k 5 30s "$SCRIP" "$w.sno" < /dev/null > "$tag.m3" 2>/dev/null ); local r3=$?
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$w.s" "$w.sno" < /dev/null > /dev/null 2>&1 && gcc "$w.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$w.4" 2>/dev/null && timeout -k 5 30s "./$w.4" < /dev/null > "$tag.m4" 2>/dev/null ); local r4=$?
  [ -s "$T/$tag.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
  if [ $r3 -eq 0 ] && cmp -s "$T/$tag.ref" "$T/$tag.m3" && [ $r4 -eq 0 ] && cmp -s "$T/$tag.ref" "$T/$tag.m4"; then return 0; fi
  echo "     m3 rc=$r3 m4 rc=$r4; ref: $(cat -v "$T/$tag.ref" | tr '\n' '/' | cut -c1-120) | m3: $(cat -v "$T/$tag.m3" | tr '\n' '/' | cut -c1-120) | m4: $(cat -v "$T/$tag.m4" | tr '\n' '/' | cut -c1-120)"; return 1; }
w1; if run_both w1 a1; then echo "  arm 1 PASS: the integer key 5, the string CHAR(1) \"i5\" and the string \"5\" are three entries, and SORT orders integer keys numerically -- equal to sbl in both modes"; else echo "  arm 1 FAIL: the collision witness diverges from sbl"; RC=1; fi
w2; if run_both w2 a2; then echo "  arm 2 PASS: a null key reads the null string, SIZE 0, through CONVERT, SORT and COPY in both modes (the tagged \"\\001n\" is gone)"; else echo "  arm 2 FAIL: the null-key witness diverges from sbl -- a tagged key string reached a program value"; RC=1; fi
w3; if run_both w3 a3; then echo "  arm 3 PASS: twelve array keys sort in creation order in both modes, as sbl orders them"; else echo "  arm 3 FAIL: aggregate keys sort out of order (the id compared as text?)"; RC=1; fi
n1=$(grep -c '\\001' "$ROOT/src/runtime/aggregates.c"); n2=$(grep -rlE 'tbl_key_str|tbl_pair_key|SCRIP_TBL_TYPED' "$ROOT/src" --include=*.c --include=*.h --include=*.cpp --include=*.inc | wc -l)
if [ "$n1" -eq 0 ] && [ "$n2" -eq 0 ]; then echo "  arm 4 PASS: no \\001 in aggregates.c and no tbl_key_str, tbl_pair_key or SCRIP_TBL_TYPED under src/"; else echo "  arm 4 FAIL: tagged spellings remain (\\001 lines in aggregates.c: $n1; files naming the retired helpers: $n2)"; RC=1; fi
echo "population: 4 arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC
