#!/usr/bin/env bash
# test_gate_icn_a_markerless_unicon_program_prints_unicons_name_form_when_the_driver_is_told_so_in_both_modes.sh -- scrip --dialect=unicon makes an Icon source that carries no
# class, package or import marker a Unicon program, exactly as if it carried one; in a Unicon program name() of a structure element is Unicon's form (table_1["abc"], list_1[1],
# record complex_1.r), and the UniTests package declares the switch in ALL.csv's compile_args for exactly its unmarked entries.
#
# WHY (cto CTO-473, 2026-11-04, on hq_unicon's ask): a program of Unicon's own tests that carries no marker is plain Icon by R1, but its ref is cut by unicon, whose name() of a table
# element is table_1["abc"] where Arizona prints T["abc"]. Option (a) ruled: the package says the program is Unicon (compile_args), the DRIVER turns the switch into the per-program
# Unicon state R1 sets from a marker (the root of the parse tree carries it; lower selects ICN$UNAME), and nothing past the driver sees a flag (CEO-1838/1840). Not the vendored
# sources (they stay verbatim) and not an exclusion (the row reads 100 over the whole package).
#
# ARMS (both modes, every expectation CUT LIVE from the oracle): nmform with --dialect=unicon against unicon; nmform with no switch against Arizona icont (the default is unchanged);
# nmformc, the same body beside a class (a marker), with no switch against unicon (the marker alone sets the state); --dialect=nosuch refused rc 2; and the package table: every
# absorbed unmarked entry of corpus/packages/icon/unicon_tests/ALL.csv declares compile_args --dialect=unicon and no marked entry does. FAIL_ONCE=1 corrupts the first arm's
# expectation. MEASURED on the parent (no switch in the driver): every switch arm refused rc 2 (unknown dialect) and the package arm found no declaration.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
UNI="$(unicon_bin)" || exit 2; [ -x "$UNI" ] || { echo "⛔ GATE REFUSE(2) [$G]: no unicon oracle at $UNI"; exit 2; }
ICONT="$(icont_bin)" || exit 2; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont oracle at $ICONT"; exit 2; }
CSV="${UNITESTS_CSV:-$ROOT/../corpus/packages/icon/unicon_tests/ALL.csv}"; [ -f "$CSV" ] || { echo "⛔ GATE REFUSE(2) [$G]: no UniTests ALL.csv at $CSV"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
BODY='procedure main();
   local T, L, c;
   T := table();
   L := list(3);
   c := complex(1,2);
   T["abc"] := 1;
   T[7] := 2;
   write(image(name(T["abc"])));
   write(image(name(T[7])));
   write(image(name(L[1])));
   write(image(name(L[-1])));
   write(image(name(c.r)));
   write(image(name(c[2])));
   write(image(name(L)));
end'
printf 'record complex(r,i)\n%s\n' "$BODY" > "$T/nmform.icn"
printf 'record complex(r,i)\nclass Marker()\nend\n%s\n' "$BODY" > "$T/nmformc.icn"
run() { local m="$1" p="$2" sw="$3"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 30s "$SCRIP" $sw --run "$p.icn" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile $sw --out="$T/$p.s" "$p.icn" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link: $(head -1 "$T/e" | cut -c1-120)"; return 99; }
  ( cd "$T" && timeout -k 5 30s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want_unicon() { rm -f "$T/$1.uni"; ( cd "$T" && timeout -k 5 120s "$UNI" -s "$1.icn" -o "$1.uni" >/dev/null 2>"$T/ue" ) || { echo "⛔ GATE REFUSE(2) [$G]: unicon would not compile $1: $(head -1 "$T/ue" | cut -c1-120)"; exit 2; }
  ( cd "$T" && timeout -k 5 30s "./$1.uni" </dev/null >"$T/$1.want" 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the unicon run of $1 failed"; exit 2; }; }
want_icont() { rm -f "$T/$1"; ( cd "$T" && timeout -k 5 120s "$ICONT" -s "$1.icn" >/dev/null 2>"$T/ie" ) || { echo "⛔ GATE REFUSE(2) [$G]: icont would not compile $1: $(head -1 "$T/ie" | cut -c1-120)"; exit 2; }
  ( cd "$T" && timeout -k 5 30s "./$1" </dev/null >"$T/$1.want" 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the icont run of $1 failed"; exit 2; }; }
arm() { local p="$1" sw="$2" who="$3" first="${4:-}" rc
  [ "$who" = unicon ] && want_unicon "$p" || want_icont "$p"
  [ -n "$first" ] && [ -n "${FAIL_ONCE:-}" ] && echo "corrupted by FAIL_ONCE" >> "$T/$p.want"
  for m in m3 m4; do run $m "$p" "$sw"; rc=$?; N=$((N + 1))
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m [$sw]: stdout byte-identical to $who ($(sed -n 1p "$T/o" | cut -c1-30))"
    else echo "  ⛔ $p $m [$sw] FAILED: rc=$rc"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
arm nmform --dialect=unicon unicon first
arm nmform "" icont
arm nmformc "" unicon
( cd "$T" && timeout -k 5 20s "$SCRIP" --dialect=nosuch --run nmform.icn </dev/null >"$T/o" 2>"$T/e" ); rc=$?; N=$((N + 1))
if [ "$rc" = 2 ] && grep -q 'nosuch' "$T/e"; then echo "  --dialect=nosuch: refused rc=2 naming the value"
else echo "  ⛔ --dialect=nosuch FAILED: rc=$rc, expected rc 2 naming the value: $(head -1 "$T/e" | cut -c1-120)"; RC=1; fi
PKG="$(dirname "$CSV")"
PK=$(python3 - "$CSV" "$PKG" "$HERE" <<'PY'
import csv, sys, os, re
csv_path, pkg, here = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, here)
src = open(os.path.join(here, 'util_build_package_suite.py')).read()
m = re.search(r'def icn_marked\(text\):.*?\n\n\n', src, re.S)
ns = {'re': re}
exec(m.group(0), ns)
marked = ns['icn_marked']
bad = []; un = 0; mk = 0; n = 0
for row in csv.DictReader(open(csv_path, newline='')):
    e = row['entry']; p = os.path.join(pkg, e + '.icn')
    if not os.path.exists(p): continue
    n += 1
    want = '' if marked(open(p, encoding='utf-8', errors='replace').read()) else '--dialect=unicon'
    if want: un += 1
    else: mk += 1
    if (row.get('compile_args') or '').strip() != want: bad.append(e + ':' + repr(row.get('compile_args')))
print('%d %d %d %s' % (n, un, mk, ' '.join(bad[:6])))
PY
)
set -- $PK; PN="${1:-0}"; PU="${2:-0}"; PM="${3:-0}"; shift 3 2>/dev/null; PBAD="$*"; N=$((N + 1))
if [ "$PN" -gt 0 ] && [ "$PU" -gt 0 ] && [ -z "$PBAD" ]; then echo "  UniTests ALL.csv: $PN entries, $PU unmarked declare --dialect=unicon, $PM marked declare none"
else echo "  ⛔ UniTests ALL.csv FAILED: $PN entries, $PU unmarked, $PM marked, mismatched: ${PBAD:-none}"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: --dialect=unicon sets the Unicon state, name() prints Unicon's form in both modes, the default is unchanged, a marker alone sets the state, the package declares the switch for its unmarked entries, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs, one refusal and the package table over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $UNI, $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
