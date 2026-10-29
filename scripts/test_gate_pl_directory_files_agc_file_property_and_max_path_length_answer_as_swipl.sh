#!/usr/bin/env bash
# test_gate_pl_directory_files_agc_file_property_and_max_path_length_answer_as_swipl.sh -- IN THE SWI DIALECT directory_files/2 ON A
# MISSING DIRECTORY IS existence_error(file, D) AND ON A FILE existence_error(directory, D); statistics(agc, N) COUNTS
# garbage_collect_atoms/0; predicate_property(M:P, file(F)) NAMES THE SOURCE FILE, CALLED DIRECTLY AND THROUGH call/1; AND A PATH
# OR PATH PART OF 4096 BYTES OR MORE IS representation_error(max_path_length), AS swipl ANSWERS (cfo 2026-10-14, row
# prolog-swi-files-test-files-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# SWI's files/test_files.pl read 10/16 in both modes. The cures: the directory_files/2 leaf (src/runtime/by_name_dispatch.c) answers
# ENOENT/ENOTDIR with swipl's existence errors in the SWI dialect (the GNU dialect keeps gprolog's system_error); statistics(agc, N)
# and garbage_collect_atoms/0 are base prelude predicates over one nb_setval counter (SCRIP collects no atoms; each call is one pass);
# the lowerer records each predicate's :file in its pred-table entry, a compile-time predicate_property/2 adds file(Abs) (realpath)
# for a static predicate of a user source, and the Prolog declaration table carries the same file as a kind-4 entry
# {atom, arity, 4, file atom} that rt_pl_db_decls_install stores on the key, so the run-time road (plunit calls each test body) answers
# static, file(F), defined in swipl's relative order; a module qualifier M:P is stripped on both roads, an unbound M bound to user.
# file_base_name/2 and file_directory_name/2 raise when the ANSWER is 4096 bytes or more and absolute_file_name/3 when the SPEC is,
# the thresholds swipl 9.0.4 measured at 4095/4096 (its PATH_MAX). NOT HERE: the module an unbound M names in a module file (swipl
# binds the file's module, SCRIP has one flat module and binds user), and exists_file/1's own limit.
#
# THE ARMS: one program, fourteen properties, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the
# parent 25c9c0f61 rebuilt: 9 of 14 lines differ in both modes; with the cure 14 of 14 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_directory_files_agc_file_property_and_max_path_length_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- module(w, []).
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), ( atom(R), atom_length(R, L), L > 60 -> sub_atom(R, 0, 20, _, R1) ; R1 = R ), writeq(N-R1), nl.
seg(N, S) :- length(L, N), maplist(=(a), L), atom_chars(S, L).
magic_pred_123.
in_dir(F) :- file_directory_name(F, D), file_base_name(F, B), directory_files(D, Fs), memberchk(B, Fs).
main :- t(dirfiles_missing, directory_files(magic_nosuch_dir_9, _)),
    t(dirfiles_not_a_dir, directory_files('w.pl', _)),
    t(agc_counts, (statistics(agc, A0), garbage_collect_atoms, statistics(agc, A1), A1 > A0)),
    t(pp_file_direct, (once(predicate_property(_:magic_pred_123, file(F1))), file_base_name(F1, B1), B1 == 'w.pl', in_dir(F1))),
    G = predicate_property(M:magic_pred_123, file(F2)), t(pp_file_called, (call(G), nonvar(M), file_base_name(F2, 'w.pl'), in_dir(F2))),
    t(pp_order, findall(P, (predicate_property(magic_pred_123, P), memberchk(P, [static, file(_), defined])), [static, file(_), defined])),
    seg(4095, S5), seg(4096, S6), seg(40000, S40), atomic_list_concat([S40, abc], /, P40),
    t(fbn_4095, file_base_name(S5, _)), t(fbn_4096, file_base_name(S6, _)),
    t(fdn_4096_seg, (file_directory_name(S6, D6), D6 == '.')), t(fdn_40000_dir, file_directory_name(P40, _)),
    t(afn_4095, absolute_file_name(S5, _, [access(read), file_errors(fail)])), t(afn_4096, absolute_file_name(S6, _, [access(read)])),
    t(fdn_abc, (file_directory_name(abc, D), D == '.')), t(fbn_slash, (file_base_name('aaa/', B), B == aaa)).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 14 ] || refuse "swipl did not answer the fourteen properties: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 14 of 14 lines as swipl"
    else echo "  $label RED: $n of 14 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
