# lib_fmt2_fixture.sh -- sourced by the format-2 writer probes (CIO-45 (1) b): fmt2_fixture ROOT builds ROOT/corpus/tests/snobol4, a scratch
# copy of the snobol4 master at the tree under test holding its container files alone (ALL.*, ONE.*, MULTI.md, PARTITION.tsv, EXCLUDED.tsv,
# ORACLE_ACCEPTANCE.tsv, REF-PINS.md and config without its loose programs), in format 2 (regrouped here when the master is not yet).
# Returns 0, or 2 with a message when it cannot build one. Needs H (corpus_suite_harness.py) and S4E (the root under test).
fmt2_fixture() {
  local root=$1 src="$S4E/corpus/tests/snobol4" d="$1/corpus/tests/snobol4" f
  [ -f "$src/ALL.csv" ] || { echo "no snobol4 master at $src"; return 2; }
  mkdir -p "$d" || return 2
  for f in "$src"/ALL.* "$src"/ONE.* "$src"/MULTI.md "$src"/PARTITION.tsv "$src"/EXCLUDED.tsv "$src"/ORACLE_ACCEPTANCE.tsv "$src"/REF-PINS.md; do
    [ -f "$f" ] && cp -p "$f" "$d/"
  done
  if [ -d "$src/config" ]; then cp -a "$src/config" "$d/config" && rm -f "$d"/config/*.sno "$d"/config/*.ref; fi
  if [ ! -f "$d/MULTI.md" ]; then
    python3 "$H" regroup "$d" > "$root/regroup.log" 2>&1 || { echo "regroup of the fixture refused: $(tail -2 "$root/regroup.log" | tr '\n' ' ')"; return 2; }
  fi
  [ -f "$d/MULTI.md" ] && [ ! -e "$d/ALL.sno" ] || { echo "the fixture is not format 2"; return 2; }
}

# fmt2_entries D OUT: write one line a test of the folder D as the format-2 reader reads it (name, kind, every attribute), for a comparison.
fmt2_entries() {
  python3 - "$(dirname "$H")" "$1" > "$2" <<'PY'
import sys; from pathlib import Path
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
for e in h.read_container_dir(Path(sys.argv[2]), ".sno"):
    v = {k: x for k, x in vars(e).items() if k != "seq"}
    print(e.name, repr(sorted(v.items())))
PY
}
