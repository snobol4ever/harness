#!/usr/bin/env bash
# util_rtx_arith_intstr_sbl_cut.sh -- the int-string arm of the arith leaves cut against sbl (the cto's condition 2 on
# rtx_int_str_operand, 2026-10-09). Each edge form of rtx_arith_test.c meets an integer on either side of + - * in its own
# SNOBOL4 program (an arithmetic error ends a run); scrip mode 3, scrip mode 4 and the SPITBOL correctness oracle (-bf) must
# print the same stdout and agree on success or failure (sbl reports an error on stdout with status 0, so its ERROR line is the verdict). rtx_arith_test.c holds the leaf to the C twin bit for bit, so a
# PASS here closes the chain leaf = twin = sbl. EXIT 0 every form agrees, 1 a divergence (named), 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin 2>/dev/null)"; [ -x "${SBL:-}" ] || { echo "REFUSED(2): the SPITBOL correctness oracle is absent"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip is not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
FORMS=( "" " " "12" " 12 " "	7	" "+5" "-5" "-0" "+0" " -0 " "+" "-" "- 5" "1 2" "7 x" "12abc" "0x10" "1.5" "abc"
        "0000000000000000000000000000001" "1234567890123456789" "12345678901234567890" "9223372036854775807"
        "-9223372036854775808" "9223372036854775808" "-9223372036854775809" "3037000500" )
n=0; bad=0
for f in "${FORMS[@]}"; do
  for op in '+' '-' '*'; do
    for side in L R; do
      n=$((n + 1)); p="$W/t$n.sno"
      if [ "$side" = L ]; then e="A $op B"; else e="B $op A"; fi
      printf "        A = '%s'\n        B = 1\n        OUTPUT = %s  :S(END)\n        OUTPUT = 'FAILED'\nEND\n" "$f" "$e" > "$p"
      if [ "$f" = "3037000500" ] && [ "$op" = '*' ]; then sed -i 's/B = 1/B = 3037000500/' "$p"; fi
      o3="$(cd "$W" && timeout -k 5 20 "$ROOT/scrip" "$p" < /dev/null 2>/dev/null)"; r3=$?
      o4=""; r4=99
      if (cd "$W" && "$ROOT/scrip" --compile -o "$W/t.s" "$p" < /dev/null >/dev/null 2>&1) && gcc "$W/t.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/t" 2>/dev/null; then
        o4="$(cd "$W" && timeout -k 5 20 "$W/t" < /dev/null 2>/dev/null)"; r4=$?
      fi
      os="$(cd "$W" && timeout -k 5 20 "$SBL" -bf "$p" < /dev/null 2>&1)"; rs=$?
      ks=ok; if [ $rs -ne 0 ] || printf '%s\n' "$os" | grep -qE ': ERROR [0-9]+ --'; then ks=err; os=""; fi
      k3=$([ $r3 -eq 0 ] && echo ok || echo err); k4=$([ $r4 -eq 0 ] && echo ok || echo err)
      if [ "$o3" != "$os" ] || [ "$o4" != "$os" ] || [ "$k3" != "$ks" ] || [ "$k4" != "$ks" ]; then
        bad=$((bad + 1)); printf "DIVERGE '%s' %s side=%s  m3=[%s]%s m4=[%s]%s sbl=[%s]%s\n" "$f" "$op" "$side" "$o3" "$k3" "$o4" "$k4" "$os" "$ks"
      fi
    done
  done
done
echo "INTSTR-SBL-CUT forms=${#FORMS[@]} programs=$n divergences=$bad"
[ "$bad" -eq 0 ]
