#!/usr/bin/env bash
# test_gate_pl_write_term_variable_names_take_unicode_uppercase_names.sh -- write_term/2,3's variable_names(['Γβα'=V]) WRITES Γβα, AS
# swipl DOES; ONLY A NAME THAT IS NOT A VARIABLE NAME IS domain_error(variable_name, N) (cfo 2026-10-14, row prolog-logtalk-reads-100-
# percent-...-ceo-1689: Logtalk case_variables lgt_unicode_non_ground_compound_term_writing, red since aa994261c).
#
# aa994261c (write_term takes partial/max_text/...) checks each variable_names name with pl_var_name_ok, which read the name with ASCII
# isupper/isalnum, so a name whose first character is a Unicode capital (Γβα, Ölçü) raised domain_error(variable_name, 'Γβα') where
# swipl writes it. The check now reads a non-ASCII character through the Prolog reader's own classifier (prolog_u_letter,
# src/parsers/prolog/prolog_lex.c -- the test that makes Γβα a variable when it is READ): the first character is '_', an ASCII
# capital or a Unicode capital (class 1); the rest are letters, digits or '_'. swipl 9.0.4 answers the six shapes below exactly so,
# a lower-case first letter and the titlecase ǅ (U+01C5) refused; gprolog 1.6.0 writes all six (it checks no name).
#
# THE ARMS: one program, six shapes, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent
# 2781bf6e4 rebuilt: 2 of 6 lines differ in both modes (Γβα and Ölçü raised domain_error); with the cure 6 of 6 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_write_term_variable_names_take_unicode_uppercase_names
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
t(N) :- catch((write_term(f(V), [variable_names([N=V])]), nl), error(E, _), (writeq(ex(E)), nl)).
main :- t('Γβα'), t('_x'), t('Ab'), t(ab), t('Ölçü'), t('ǅx').
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 6 ] || refuse "swipl did not answer the six shapes: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 6 of 6 lines as swipl"
    else echo "  $label RED: $n of 6 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
