#!/usr/bin/env bash
# test_gate_pl_open_a_file_it_may_not_open_is_a_permission_error.sh -- OPEN/3,4 ON A FILE THE PROCESS MAY NOT OPEN RAISES
# permission_error(open, source_sink, F); ONLY A MISSING FILE OR DIRECTORY IS existence_error(source_sink, F) (cfo 2026-10-11, row
# prolog-logtalk-reads-100-percent-...-ceo-1689: Logtalk open_4 lgt_open_4_27..30, graded since the instrument change 5e21752da).
#
# pl_open_leaf (src/runtime/by_name_dispatch.c) answered every fopen failure existence_error(source_sink, F). ISO 8.11.5.3 makes
# "the source/sink cannot be opened" a permission_error(open, source_sink, F), and both oracles measured agree, shape for shape:
# a file without read permission opened for read, a file without write permission opened for write and for append, a write in /,
# each permission_error; a write under a directory that does not exist and a read of a file that does not exist, each
# existence_error. errno EACCES, EPERM and EROFS now read permission_error. NOT HERE: a directory opened for write (EISDIR), where
# gprolog 1.6.0 answers permission_error and swipl 9.0.4 existence_error -- a dialect split, and SCRIP keeps swipl's answer.
#
# THE ARMS: one program, six shapes, stdout cut against gprolog in this run, in mode 3 and mode 4. A run as root refuses (rc=2):
# chmod cannot take a permission away from root, so the arms would measure nothing. FAIL-ONCE, measured on the parent 5e21752da
# rebuilt: 4 of 6 lines differ in both modes (existence_error for each permission shape); with the cure 6 of 6 as gprolog.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no gprolog, no build, root).  ~2 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_open_a_file_it_may_not_open_is_a_permission_error
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
GP="$(gprolog_bin)"; [ -x "$GP" ] || refuse "no gprolog at $GP -- the oracle (gprolog_bin, ORACLES.md: a bare gprolog on PATH is the retired 1.4.5)"
[ "$(id -u)" != 0 ] || refuse "running as root: chmod cannot take a permission away, so no arm would measure anything"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'chmod -R u+rw "$D" 2>/dev/null; rm -rf "$D"' EXIT
echo 'foo.' > "$D/nr" && chmod a-r "$D/nr" || refuse "could not make the unreadable fixture"
echo 'foo.' > "$D/nw" && chmod a-w "$D/nw" || refuse "could not make the unwritable fixture"
cat > "$D/w.pl" <<'PL'
t(N, F, M) :- catch((open(F, M, S), close(S), R = ok), error(E, _), R = E), write('@ '), write(N), write(' '), writeq(R), nl.
:- initialization(main).
main :- t(noread, nr, read), t(nowrite, nw, write), t(noappend, nw, append), t(rootwrite, '/no_write_permission', write),
    t(missing_dir, 'no/such/dir/x', write), t(missing_file, nosuchfile, read).
PL
want="$(cd "$D" && timeout -k 5 20 "$GP" --consult-file w.pl --query-goal halt < /dev/null 2>&1 | grep '^@ ')"
[ "$(printf '%s\n' "$want" | grep -c '^@ ')" = 6 ] || refuse "gprolog did not answer the six shapes: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>&1 | grep '^@ ')"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 6 of 6 lines as gprolog"
    else echo "  $label RED: $n of 6 lines differ from gprolog"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
