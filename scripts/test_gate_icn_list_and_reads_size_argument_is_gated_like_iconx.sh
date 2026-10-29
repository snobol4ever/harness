#!/usr/bin/env bash
# test_gate_icn_list_and_reads_size_argument_is_gated_like_iconx.sh -- cfo 2026-09-10,
# pinning the un-gated half of the cfo's 118fe2e4a (hq_C named the hole in mail the same evening).
#
# WHAT IT PINS. The SIZE argument of list(n) and reads(f,n) is gated by iconx before the builtin runs, and the
# two rejections are DIFFERENT ERRORS carrying the operand: a size that cannot convert to integer raises 101
# "integer expected or out of range" with the offending value, and a size that converts but is OUT OF RANGE
# raises 205 "invalid value" with the converted value. The ranges differ per builtin and that difference is the
# point: a list may be created with size 0 (n < 0 raises) while reads must be asked for at least one character
# (n < 1 raises), so reads(f,0) is a 205 where list(0) is a perfectly good empty list.
#
# ⛔ THE FALSE GREEN THIS GATE EXISTS TO REFUSE, and why every arm runs BEHIND A PRIMER. &errornumber,
# &errortext and &errorvalue all hold the PREVIOUS error's content. A build in which these gates were never
# wired does not report a wrong number -- the expression simply FAILS, silently, raising nothing at all, and the
# three keywords still read whatever the last error left there. So "the gate raised 101 with the value" and "the
# gate raised nothing and you are reading a corpse" render IDENTICALLY unless an unrelated error runs first.
# Every arm below is preceded by `&error := -1; (1 + "q")`, which raises 102 with the value "q" -- a number that
# answers NO case in this population and a value that matches no operand in it. An un-cured build therefore
# reads 102 on all five raising arms instead of 101/205, which is exactly what the control run measured.
# ⛔ The operands are deliberately "zz", -7, "ww", 0, -3 -- all distinct from the primer's "q" -- so that
# &errorvalue is graded against THIS expression's operand and cannot be satisfied by the primer's leftovers.
#
# ⛔ THE SIX ACCEPTING ARMS ARE THE CONTROL AND MUST STAY GREEN ON BOTH ARMS OF THE A/B. A size gate that
# rejects too eagerly greens the five raising arms and quietly breaks every legitimate call: a CONVERTIBLE
# STRING size is accepted (list("3") is a 3-element list, reads(f,"2") reads two characters), a real size is
# accepted and truncated (list(3.7) has 3 elements), list(0) and list() are empty lists, and reads(f) with no
# size at all reads one character. These read the primer's own 102 back out, which is the same instrument the
# raising arms use, pointed the other way: here 102 PROVES no error was raised.
#
# ⭐ WATCHED GO BOTH WAYS (CEO-381), MEASURED not assumed: with ONLY src/runtime/by_name_dispatch.c restored to
# its 118fe2e4a^ content and the runtime rebuilt, this gate reads rc=1 with 12 of the 22 arms diverging, and it
# is worth reading WHICH 12. The five raising arms x 2 modes all answer the primer's `n=102 v="q" t="numeric
# expected"` -- the corpse, not a wrong answer of their own, which is the whole reason the primer is there. The
# sixth pair is LIST_CVT, which goes <absent> in both modes: on the pre-cure build list("3") did not raise, it
# simply FAILED, so its write never ran. That is the accepting side proving it is not decoration -- the
# convertible-string size was broken too, in a different function (try_call_builtin_by_name_bl), and a gate
# carrying only the five raising arms would have pinned half a cure. The other ten arms stay green on BOTH arms
# of the A/B, which is what makes them controls. Cured tree: 22/22, rc=0, ~0.15s.
# Every want is cut from a FRESHLY BUILT icont/iconx at run time, never a stored .ref.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
R="$PWD"
[ -x "$R/scrip" ] || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: scrip not built -- measured nothing."; exit 2; }
[ "$R/scrip" -nt "$R/src/runtime/by_name_dispatch.c" ] || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: ./scrip is older than src/runtime/by_name_dispatch.c -- a stale binary measures the previous tree. Run make."; exit 2; }
ICONT=/home/resources/icon-master/bin/icont
ICONX=/home/resources/icon-master/bin/iconx
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: no Arizona oracle at $ICONT / $ICONX -- measured nothing."; exit 2; }
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
printf 'so far and further\n' > "$T/in.txt"
cat > "$T/g.icn" <<'ICN'
procedure main();
   local f, L, s;
   f := open("__IN__", "r") | stop("cannot open the fixture");
   &error := -1; (1 + "q"); L := list("zz");
   write("LIST_STR n=", &errornumber, " v=", image(&errorvalue), " t=", image(&errortext));
   &error := -1; (1 + "q"); L := list(-7);
   write("LIST_NEG n=", &errornumber, " v=", image(&errorvalue), " t=", image(&errortext));
   &error := -1; (1 + "q"); s := reads(f, "ww");
   write("READS_STR n=", &errornumber, " v=", image(&errorvalue), " t=", image(&errortext));
   &error := -1; (1 + "q"); s := reads(f, 0);
   write("READS_ZERO n=", &errornumber, " v=", image(&errorvalue), " t=", image(&errortext));
   &error := -1; (1 + "q"); s := reads(f, -3);
   write("READS_NEG n=", &errornumber, " v=", image(&errorvalue), " t=", image(&errortext));
   &error := -1; (1 + "q"); L := list("3");
   write("LIST_CVT n=", &errornumber, " size=", image(*L));
   &error := -1; (1 + "q"); L := list(3.7);
   write("LIST_REAL n=", &errornumber, " size=", image(*L));
   &error := -1; (1 + "q"); L := list(0);
   write("LIST_ZERO n=", &errornumber, " size=", image(*L));
   &error := -1; (1 + "q"); L := list();
   write("LIST_NOARG n=", &errornumber, " size=", image(*L));
   &error := -1; (1 + "q"); s := reads(f, "2");
   write("READS_CVT n=", &errornumber, " s=", image(s));
   &error := -1; (1 + "q"); s := reads(f);
   write("READS_PLAIN n=", &errornumber, " s=", image(s));
end
ICN
sed -i "s|__IN__|$T/in.txt|" "$T/g.icn"
( cd "$T" && "$ICONT" -s -o orc g.icn ) > "$T/icont.log" 2>&1
[ -x "$T/orc" ] || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: icont refused the witness -- measured nothing:"; sed 's/^/    /' "$T/icont.log"; exit 2; }
timeout -k 5 60 "$ICONX" "$T/orc" < /dev/null > "$T/want" 2>&1 || true
timeout -k 5 60 "$R/scrip" "$T/g.icn" < /dev/null > "$T/m3" 2>&1
rm -f "$T/g.s" "$T/bin"
timeout -k 5 60 "$R/scrip" --compile --out="$T/g.s" "$T/g.icn" < /dev/null > "$T/cc.log" 2>&1
[ -s "$T/g.s" ] && gcc -m64 -no-pie "$T/g.s" -o "$T/bin" -L"$R/out" -lscrip_rt -Wl,-rpath,"$R/out" -lm -lpthread >> "$T/cc.log" 2>&1
[ -x "$T/bin" ] || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: mode 4 produced no binary -- measured nothing:"; tail -3 "$T/cc.log" | sed 's/^/    /'; exit 2; }
timeout -k 5 60 "$T/bin" < /dev/null > "$T/m4" 2>&1
grep -q '^LIST_STR ' "$T/want" || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: the oracle named no LIST_STR row -- measured nothing:"; sed 's/^/    /' "$T/want"; exit 2; }
grep -q '^LIST_STR n=101 ' "$T/want" || { echo "GATE UNPROVEN(2) [icn_list_reads_size_gate]: the oracle did not raise 101 for list(\"zz\") -- the population is not what this gate believes and its wants would pin a fiction:"; sed 's/^/    /' "$T/want"; exit 2; }
bad=0
for key in LIST_STR LIST_NEG READS_STR READS_ZERO READS_NEG LIST_CVT LIST_REAL LIST_ZERO LIST_NOARG READS_CVT READS_PLAIN; do
  w=$(grep -F "$key " "$T/want" | head -1)
  [ -n "$w" ] || { echo "  ⛔ UNPROVEN  $key: the oracle named no such row"; bad=$((bad + 1)); continue; }
  for m in m3 m4; do
    g=$(grep -F "$key " "$T/$m" | head -1)
    if [ "$g" = "$w" ]; then printf '  ✅ %-3s %-12s %s\n' "$m" "$key" "$w"
    else printf '  ⛔ %-3s %-12s want: %s\n                   got:  %s\n' "$m" "$key" "$w" "${g:-<absent>}"; bad=$((bad + 1)); fi
  done
done
echo "gate: $bad divergence(s) from the Arizona oracle, over 5 raising + 6 accepting shapes x 2 modes = 22 graded arms."
[ "$bad" -eq 0 ] || { echo "GATE FAIL [icn_list_and_reads_size_argument_is_gated_like_iconx]: the size argument of list()/reads() does not answer the way iconx answers."; exit 1; }
echo "GATE PASS [icn_list_and_reads_size_argument_is_gated_like_iconx]"
exit 0
