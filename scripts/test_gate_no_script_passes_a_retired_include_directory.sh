#!/usr/bin/env bash
# test_gate_no_script_passes_a_retired_include_directory.sh -- EVERY -I A SCRIPT HANDS THE COMPILER NAMES A DIRECTORY THAT
# EXISTS (row instruments-a-retired-include-directory-is-silently-ignored-by-gcc-so-seven-scripts-still-name-it, the cfo,
# 2026-09-28; the cto measured the class, hq_R found its first instance).
#
# THE MECHANISM, MEASURED BY THE ROW: `gcc -I<nonexistent-dir>` is not an error -- it exits 0 with no diagnostic -- so a
# retired include directory in a hand-copied -I list is harmless on every translation unit that needs no header from it and
# becomes a BUILD FAIL only on the ones that do.  src/contracts, src/machine, src/interp and src/include were merged into
# src/ir by the 2026-08-24 srcreorg (SCRIP d4312e86).  On 2026-09-28 test_sno_pat_bb_probe.sh still passed all four, and
# LACKED src/ir, where IR.h and bb_box.h now live: PASS=0 FAIL=8, every one a compile failure.  Its list now comes from the
# build's one authority (lib_build_flags.sh BF_RT_INCS), whose own load REFUSES rc=2 when the Makefile's RT_INCS names a
# missing directory -- so the Makefile side of this class is guarded there, and this gate guards the scripts.
#
# THE POPULATION: every `-I<path>` / `-I <path>` token (a word boundary before the -I, so -IDENTICAL and -INCLUDE are not
# tokens) on a non-comment line of ../harness/scripts/*.sh and ../harness/scripts/*.py.  Each token is expanded through its OWN FILE's simple
# assignments (NAME=value, one pass per reference, ROOT and SCRIP_ROOT meaning this checkout's root); a token that lands
# under <root>/src/ or a bare src/ must name an existing directory.  A token whose variables this gate cannot resolve is
# SET ASIDE AND PRINTED by variable name, never silently passed -- the reader sees what was not graded.
#
# ARMS: (1) the real tree: every dead token is DECLARED by (script, directory) in ../harness/scripts/fixtures/retired_include/DECLARED.tsv
# -- today eleven pairs in seven scripts no recipe reaches, carried for a retirement ruling -- and no declared pair is stale, the
# population and the set-aside printed; (2) FAIL-ONCE: a scratch copy of ../harness/scripts/ with two planted scripts, `-I "$ROOT/src/contracts"` and `-Isrc/machine`,
# reads RED naming both, and grown by exactly two from the unplanted count; (3) THE FOUR SITES THE ROW NAMED no longer name a
# retired directory on a non-comment line (test_census_rbp_frames.sh, test_sno_pat_bb_probe.sh, util_autobug.sh,
# util_fc_conversion_map.py), and util_fc_conversion_map.py runs to rc 0 (source only, ~1 s).  No binary is read.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
cat > "$T/scan.py" <<'PY'
import os, re, sys, glob
root, sdir, skip = sys.argv[1], sys.argv[2], sys.argv[3]
files = [f for f in sorted(glob.glob(os.path.join(sdir, '*.sh')) + glob.glob(os.path.join(sdir, '*.py'))) if os.path.basename(f) != skip]
TOK = re.compile(r'''(?:(?<=^)|(?<=[\s"'(=\[,]))-I\s*["']?([^\s"')\]]+)''')
ASSIGN = re.compile(r'''^\s*(?:export\s+|local\s+|readonly\s+)?([A-Za-z_][A-Za-z0-9_]*)=(["']?)([^"'\s;]*)\2''')
REF = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?')
def code_of(line):
    m = re.search(r'(^|\s)#', line)
    return line[:m.start()] if m else line
checked = bad = 0; unres = {}
for f in files:
    lines = open(f, errors='replace').read().split('\n')
    env = {'ROOT': root, 'SCRIP_ROOT': root}
    for l in lines:
        m = ASSIGN.match(l)
        if m and m.group(1) not in env and '$(' not in m.group(3) and '`' not in m.group(3): env[m.group(1)] = m.group(3)
    for i, l in enumerate(lines, 1):
        for t in TOK.finditer(code_of(l)):
            p = t.group(1)
            for _ in range(4):
                q = REF.sub(lambda r: env.get(r.group(1), '\0' + r.group(1) + '\0'), p)
                if q == p: break
                p = q
            if '\0' in p:
                v = re.findall(r'\0([A-Za-z_0-9]+)\0', p)[0]; unres[v] = unres.get(v, 0) + 1; continue
            if p.startswith('src/'): p = os.path.join(root, p)
            if not p.startswith(os.path.join(root, 'src')): continue
            checked += 1
            if not os.path.isdir(p):
                bad += 1; print('DEAD %s\t%s\t%d' % (os.path.relpath(f, sdir), os.path.relpath(p, root), i))
print('POPULATION checked=%d dead=%d set_aside=%d (%s)' % (checked, bad, sum(unres.values()), ' '.join('%s:%d' % kv for kv in sorted(unres.items())) or 'none'))
PY
python3 "$T/scan.py" "$ROOT" "$ROOT/../harness/scripts" "$G.sh" > "$T/real.txt" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the scanner died"; cat "$T/real.txt"; exit 2; }
pop=$(grep '^POPULATION' "$T/real.txt"); n_real=$(grep -c '^DEAD' "$T/real.txt")
checked=$(printf '%s' "$pop" | sed -n 's/.*checked=\([0-9]*\).*/\1/p')
[ "${checked:-0}" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: no -I token resolved under src/ -- the scanner measured nothing ($pop)"; exit 2; }
D="$ROOT/../harness/scripts/fixtures/retired_include/DECLARED.tsv"; [ -s "$D" ] || { echo "⛔ GATE REFUSE(2) [$G]: the declaration $D is missing"; exit 2; }
grep -vE '^#|^$' "$D" | cut -f1,2 | sort -u > "$T/decl.txt"; grep '^DEAD' "$T/real.txt" | cut -f1,2 | sed 's/^DEAD //' | sort -u > "$T/dead.txt"
undecl=$(comm -13 "$T/decl.txt" "$T/dead.txt"); stale=$(comm -23 "$T/decl.txt" "$T/dead.txt"); ndecl=$(grep -c . "$T/decl.txt")
if [ -z "$undecl" ] && [ -z "$stale" ]; then echo "  arm 1 PASS: no UNDECLARED dead -I in scripts; $ndecl (script, directory) pair(s) carried by name in DECLARED.tsv, each still dead -- $pop"
else [ -n "$undecl" ] && { echo "  arm 1 FAIL: dead -I token(s) no declaration carries (gcc accepts them in silence) -- repoint through lib_build_flags.sh or declare with a reason:"; printf '%s\n' "$undecl" | sed 's/^/     /'; }
     [ -n "$stale" ] && { echo "  arm 1 FAIL: STALE declaration(s) -- no longer dead; remove the row in the landing that cured it:"; printf '%s\n' "$stale" | sed 's/^/     /'; }; RC=1; fi
mkdir -p "$T/plant" && cp "$ROOT"/../harness/scripts/*.sh "$ROOT"/../harness/scripts/*.py "$T/plant/" 2>/dev/null
printf '#!/usr/bin/env bash\nROOT=x\ngcc -I "$ROOT/src/contracts" -c a.c\n' > "$T/plant/zz_planted_retired_a.sh"
printf '#!/usr/bin/env bash\ngcc -Isrc/machine -c b.c\n' > "$T/plant/zz_planted_retired_b.sh"
python3 "$T/scan.py" "$ROOT" "$T/plant" "$G.sh" > "$T/plant.txt" 2>&1
n_plant=$(grep -c '^DEAD' "$T/plant.txt")
if [ "$n_plant" -eq $((n_real + 2)) ] && grep -qP 'zz_planted_retired_a.sh\tsrc/contracts' "$T/plant.txt" && grep -qP 'zz_planted_retired_b.sh\tsrc/machine' "$T/plant.txt"; then echo "  arm 2 PASS: the two planted retired directories read RED by file and path, dead $n_real -> $n_plant"
else echo "  arm 2 FAIL: the plant read dead $n_real -> $n_plant, want +2 naming src/contracts and src/machine -- the scanner cannot see the class"; RC=1; fi
stale=0; for f in test_census_rbp_frames.sh test_sno_pat_bb_probe.sh util_autobug.sh util_fc_conversion_map.py; do
  h=$(grep -nE 'src/(contracts|machine|interp|include)\b' "$ROOT/../harness/scripts/$f" | grep -vE '^[0-9]+:\s*#' | head -1); [ -n "$h" ] && { echo "     $f:$h"; stale=$((stale+1)); }; done
( cd "$ROOT" && timeout -k 5 60 python3 ../harness/scripts/util_fc_conversion_map.py > "$T/fc.txt" 2>&1 ); fcr=$?
if [ "$stale" -eq 0 ] && [ "$fcr" -eq 0 ] && [ -s "$T/fc.txt" ]; then echo "  arm 3 PASS: the four scripts the row named read no retired directory on a code line, and util_fc_conversion_map.py runs rc=0 ($(wc -l < "$T/fc.txt") lines)"
else echo "  arm 3 FAIL: $stale of the four scripts still name a retired directory on a code line; util_fc_conversion_map.py rc=$fcr"; RC=1; fi
echo "population: 3 arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC
