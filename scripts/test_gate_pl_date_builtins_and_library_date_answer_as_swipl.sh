#!/usr/bin/env bash
# test_gate_pl_date_builtins_and_library_date_answer_as_swipl.sh -- stamp_date_time/3, date_time_stamp/2 AND format_time/3,4 EXIST AND
# ANSWER AS swipl, AND library(date)'s parse_time/2,3, day_of_the_week/2, day_of_the_year/2 AND date_time_value/3 RUN OVER THEM (cfo
# 2026-10-14, row prolog-swi-library-test-date-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# SWI's library/test_date.pl read 2/15 in both modes: none of the three builtins existed. They are run-time leaves now
# (src/runtime/by_name_dispatch.c, $stamp_date_time/$date_time_stamp/$format_time_text, wired as nb_linkarg is): a stamp converts by
# gmtime_r for 'UTC' and an integer offset (seconds west, as SWI counts it) and by localtime_r for local (offset, zone name and DST
# from the C library); a date/9 converts by a civil-days count with month and day overflow normalised as SWI does, a date/3 is local
# midnight (mktime); format_time/3,4 (base prelude) hands its sink -- atom/string/codes/chars or a stream -- the text the leaf builds:
# strftime for every directive but SWI's own %f / %Nf (the fraction rounded to microseconds, then truncated to N digits: 0.9 is "900",
# 0.9999 is "999"), %:z, %+ and %s. library(date) is swipl's, vendored byte-identical (src/parsers/prolog/prelude/date.pl). swipl runs
# under LC_ALL=C here because %c, %x, %p and the day and month names follow the locale and SCRIP's run time is the C locale. NOT HERE:
# format_time/4's locale argument (ignored), a locale other than C, and stamps past the 64-bit time_t range.
#
# THE ARMS: one program, fifty-nine lines, stdout cut against swipl (LC_ALL=C) in this run, mode 3 and mode 4, in the same time zone.
# FAIL-ONCE, measured on the parent 3791c84ae rebuilt: 30 of 59 lines differ in both modes; with the cure 59 of 59 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_date_builtins_and_library_date_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
main :- t(sdt_utc, (stamp_date_time(1165591784, D, 'UTC'), writeq(D), nl)), t(sdt_local, (stamp_date_time(1165591784, D2, local), writeq(D2), nl)),
  t(sdt_off, (stamp_date_time(0, D3, 0), writeq(D3), nl)), t(sdt_off2, (stamp_date_time(0, D4, 3600), writeq(D4), nl)),
  t(sdt_frac, (stamp_date_time(100000.25, D5, 'UTC'), writeq(D5), nl)), t(sdt_neg, (stamp_date_time(-7506086400, D6, 'UTC'), writeq(D6), nl)),
  t(dts9, (date_time_stamp(date(2006,12,8,17,29,44,-7200,-,-), S1), writeq(S1), nl)), t(dts_tz, (date_time_stamp(date(1970,1,1,0,0,0,-3600,-,-), S2), writeq(S2), nl)),
  t(dts3, (date_time_stamp(date(2006,12,8), S3), writeq(S3), nl)), t(dts_norm, (date_time_stamp(date(2006,13,40,25,61,61,0,-,-), S4), writeq(S4), nl)),
  t(dts_local, (date_time_stamp(date(2006,12,8,0,0,0,-,-,-), S5), writeq(S5), nl)), t(dts_float, (date_time_stamp(date(2006,12,8,0,0,1.5,0,-,-), S6), writeq(S6), nl)),
  t(ft1, (format_time(atom(A1), '%Y-%m-%d', -7506086400), writeq(A1), nl)), t(ft2, (format_time(atom(A2), '%FT%T%z %Z %a %b %e %j %u %w %H:%M:%S %3f %f %s', 1165591784.123456), writeq(A2), nl)),
  t(ft3, (format_time(string(A3), '%3f', -100000.9), writeq(A3), nl)), t(ft4, (format_time(atom(A4), '%FT%T%:z', date(2006,12,8,17,29,44,-7200,-,-)), writeq(A4), nl)),
  t(ft5, (format_time(codes(A5), '%d', date(2006,12,8)), writeq(A5), nl)), t(ft6, (format_time(atom(A6), '%A %B %p %I %y %C %G %V %U %W %D %R %r %c', 1165591784), writeq(A6), nl)),
  t(ft7, (format_time(atom(A7), '%+', 0), writeq(A7), nl)), t(ft8, (format_time(atom(A8), '%%|%n|%t|%k|%l|%P|%h', 0), writeq(A8), nl)),
  t(pt1, (parse_time('2006-12-08T17:29:44+02:00', iso_8601, T1), writeq(T1), nl)), t(pt2, (parse_time('20061208T172944+0200', iso_8601, T2), writeq(T2), nl)),
  t(pt3, (parse_time('2006-W49-5', iso_8601, T3), writeq(T3), nl)), t(pt4, (parse_time('2006-342', iso_8601, T4), writeq(T4), nl)), t(pt5, (parse_time('2006-12', iso_8601, T5), writeq(T5), nl)),
  t(pt_rfc, (parse_time('Fri, 08 Dec 2006 15:29:44 GMT', rfc_1123, T6), writeq(T6), nl)), t(pt_any, (parse_time('2006-12-08T15:29Z', T7), writeq(T7), nl)),
  t(dow, (day_of_the_week(date(2006,12,8), W), writeq(W), nl)), t(doy, (day_of_the_year(date(2006,12,8), Yd), writeq(Yd), nl)), t(dtv, (date_time_value(month, date(2006,12,8,0,0,0,0,-,-), Mo), writeq(Mo), nl)).
PL
want="$(cd "$D" && LC_ALL=C LANG=C timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 59 ] || refuse "swipl did not answer the fifty-nine lines: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 59 of 59 lines as swipl"
    else echo "  $label RED: $n of 59 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
