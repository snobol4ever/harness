#!/usr/bin/env bash
# util_eval_number_strings_answer_like_spitbol.sh -- the DONE-WHEN of row snobol4-eval-of-a-blank-padded-integer-and-a-leading-point-real-
# diverges-from-spitbol (ceo 2026-09-25): EVAL of number-shaped strings answers what sbl -bf answers, in m3 and m4. rc 0 / 1 red / 2 could not run.
R="${S4E_HOME:-/home/claude_ceo}/SCRIP"; W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W" || exit 2
printf "        OUTPUT = EVAL('  12 ')\n        OUTPUT = DATATYPE(EVAL('  12 '))\n        OUTPUT = EVAL('.5')\n        OUTPUT = EVAL('-3.5')\n        OUTPUT = EVAL('1e3')\n        OUTPUT = 'end'\nEND\n" > e.sno
want="$(/home/resources/x64/bin/sbl -bf e.sno < /dev/null 2>/dev/null)"; [ -n "$want" ] || exit 2
m3="$(timeout -k 5 30 "$R/scrip" e.sno < /dev/null 2>/dev/null)"
"$R/scrip" --compile -o e.s e.sno < /dev/null > /dev/null 2>&1 && gcc e.s -L"$R/out" -lscrip_rt -lm -Wl,-rpath,"$R/out" -o e.bin 2>/dev/null || exit 2
m4="$(timeout -k 5 30 ./e.bin < /dev/null 2>/dev/null)"
[ "$m3" = "$want" ] && [ "$m4" = "$want" ] && { echo "GREEN: EVAL of number-shaped strings answers the oracle in m3 and m4"; exit 0; }
echo "RED: oracle [$(echo $want)] m3 [$(echo $m3)] m4 [$(echo $m4)]"; exit 1
