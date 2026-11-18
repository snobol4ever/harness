#!/bin/bash
# test_scriptix_pairs_kernel_road.sh -- THE PAIRS' REAL-KERNEL ROAD (the cao 2026-11-18, row jupyter-the-pairs-notebooks-run-in-a-real-jupyter-each-cell-tagged-by-its-first-line, part b1; Lon's Lab is the road nobody graded).
# For every pair of tests/scriptix/variables and tests/scriptix/functions whose NAME.md reads its NAME.out on the file road (scrip NAME.md) AND whose cells read it on the session-host road
# (util_pairs_session_drive.py, the code cells sent to scrip --session as the kernel sends them, the %% first line taken off), NAME.ipynb is executed by jupyter nbconvert --execute
# through a kernel spec made of the built $S4E_SCRIP/scrip in a scratch JUPYTER_PATH (never an installed spec; refused rc 2 unless the spec scrip resolves to the scratch folder with argv[0] the S4E_SCRIP binary),
# a client that sends no cell metadata, and the text of its code cells' stdout streams is compared byte for byte with NAME.out; a stderr stream or an error output in a cell is a DIFFERS. Mode 3 only.
# A pair with a red of its own on the file road or the session host is skipped and counted, never read as a green.
#   one line a pair: SAME, DIFFERS (the first differing line and the cell's stderr), SKIP (which road), UNMEASURED; then REALKERNEL pairs= same= differs= skipped_for_a_red_of_their_own= unmeasured=
#   rc 0 every measured pair equal; rc 1 a pair differs; rc 2 could not measure (no binary, no jupyter, no pairs, no kernel, a spec that does not resolve to the scratch folder).
#   PAIRS_JOBS (default 4) runs that many notebooks at once; REALKERNEL_ONLY (a space list of set/NAME) limits the run to those pairs.
: "${S4E_SCRIP:?REFUSE(2): S4E_SCRIP unset}"
HARN="${S4E_HARNESS:-/home/harness}"
. "$HARN/scripts/lib_paths.sh"
S="$S4E_SCRIP/scrip"
DRIVE="$HARN/scripts"
TOP="$S4E_CORPUS/tests/scriptix"
if [ "$1" = "--one" ]; then
  set_="$2"; name="$3"; W="$4"
  d="$TOP/$set_"
  tag="$set_-$name"
  mkdir -p "$W/$tag"
  fr="$(cd "$d" && timeout -k 5 120 "$S" "$name.md" 2>&1 < /dev/null)"
  if [ "$fr" != "$(cat "$d/$name.out")" ]; then echo "SKIP $tag file road does not read its answer"; exit 0; fi
  python3 -I -c 'import json,sys
nb=json.load(open(sys.argv[1]))
for c in nb["cells"]:
    if c["cell_type"]!="code": continue
    src="".join(c["source"])
    if src.startswith("%%"): src=src.split("\n",1)[1] if "\n" in src else ""
    print("=== "+c["metadata"]["scrip"]["language"]); print(src,end="")' "$d/$name.ipynb" > "$W/$tag/cells"
  printf '```SNOBOL4\nEND\n```\n' > "$W/$tag/boot.md"
  sh="$(cd "$W/$tag" && timeout -k 5 120 python3 "$DRIVE/util_pairs_session_drive.py" "$S" boot.md "$W/$tag/cells" 2>&1 < /dev/null | grep -v '^\[GC-')"
  if [ "$(printf '%s\n' "$sh" | grep -v '^--- ')" != "$(cat "$d/$name.out")" ] || printf '%s\n' "$sh" | grep -q '^--- DONE error'; then echo "SKIP $tag session-host road does not read its answer"; exit 0; fi
  cp "$d/$name.ipynb" "$W/$tag/in.ipynb"
  (cd "$W/$tag" && JUPYTER_RUNTIME_DIR="$W/$tag/rt" timeout -k 5 300 jupyter nbconvert --to notebook --execute --allow-errors --ExecutePreprocessor.timeout=120 --output out.ipynb in.ipynb > run.log 2>&1 < /dev/null)
  rc=$?
  if [ ! -f "$W/$tag/out.ipynb" ]; then echo "UNMEASURED $tag nbconvert rc $rc: $(tail -2 "$W/$tag/run.log" | tr '\n' ' ' | cut -c1-200)"; exit 0; fi
  python3 -I - "$W/$tag/out.ipynb" "$d/$name.out" "$tag" <<'PY'
import json, sys
nb = json.load(open(sys.argv[1]))
want = open(sys.argv[2]).read()
tag = sys.argv[3]
got = []
bad = []
for i, c in enumerate(nb["cells"], 1):
    if c.get("cell_type") != "code":
        continue
    for o in c.get("outputs", []):
        t = o.get("text", "")
        t = "".join(t) if isinstance(t, list) else t
        if o.get("output_type") == "stream" and o.get("name") == "stdout":
            got.append(t)
        elif o.get("output_type") == "stream":
            bad.append("cell %d stderr: %s" % (i, t.strip()[:120].replace("\n", " | ")))
        elif o.get("output_type") == "error":
            bad.append("cell %d error: %s: %s" % (i, o.get("ename"), str(o.get("evalue"))[:120].replace("\n", " | ")))
got = "".join(got)
if got == want and not bad:
    print("SAME " + tag)
else:
    first = next((k for k, (a, b) in enumerate(zip(got.split("\n"), want.split("\n")), 1) if a != b), min(len(got.split("\n")), len(want.split("\n"))) + 1)
    print("DIFFERS %s first line %d; got %r; want %r%s" % (tag, first, got[:100], want[:100], ("; " + "; ".join(bad[:2])) if bad else ""))
PY
  exit 0
fi
[ -x "$S" ] || { echo "REFUSE(2): no scrip binary at $S"; exit 2; }
[ -r "$DRIVE/util_pairs_session_drive.py" ] || { echo "REFUSE(2): no session driver util_pairs_session_drive.py under $DRIVE"; exit 2; }
command -v jupyter > /dev/null 2>&1 || { echo "REFUSE(2): no jupyter on the box"; exit 2; }
[ -d "$TOP/variables" ] && [ -d "$TOP/functions" ] || { echo "REFUSE(2): no tests/scriptix pairs under $TOP"; exit 2; }
W="$(mktemp -d /tmp/s4e/${S4E_SEAT:-seat}-realkernel.XXXXXX)"
trap 'rm -rf "$W"' EXIT
"$S" --kernel-install "$W/spec/kernels" > "$W/install.log" 2>&1 || { echo "REFUSE(2): scrip --kernel-install did not install the kernel: $(tail -1 "$W/install.log")"; exit 2; }
[ -f "$W/spec/kernels/scrip/kernel.json" ] || { echo "REFUSE(2): the install wrote no kernel.json"; exit 2; }
export JUPYTER_PATH="$W/spec"
rs="$(jupyter kernelspec list --json 2> /dev/null | python3 -I -c '
import json, os, sys
want_dir, want_bin = os.path.realpath(sys.argv[1]), os.path.realpath(sys.argv[2])
got = json.load(sys.stdin).get("kernelspecs", {}).get("scrip", {}).get("resource_dir")
if not got or os.path.realpath(got) != want_dir:
    print("the kernel spec scrip resolves to %s, not the scratch folder %s" % (got, want_dir)); sys.exit(1)
argv = json.load(open(os.path.join(got, "kernel.json"))).get("argv", [])
if not argv or os.path.realpath(argv[0]) != want_bin:
    print("the scratch spec argv[0] is %s, not %s" % (argv[0] if argv else None, want_bin)); sys.exit(1)
' "$W/spec/kernels/scrip" "$S" 2>&1)" || { echo "REFUSE(2): $rs"; exit 2; }
export S4E_SCRIP S4E_CORPUS
: > "$W/list"
for set_ in variables functions; do
  for f in "$TOP/$set_"/*.ipynb; do
    n="$(basename "$f" .ipynb)"
    if [ -n "$REALKERNEL_ONLY" ]; then case " $REALKERNEL_ONLY " in *" $set_/$n "*) ;; *) continue;; esac; fi
    echo "$set_ $n" >> "$W/list"
  done
done
[ -s "$W/list" ] || { echo "REFUSE(2): no pair selected"; exit 2; }
xargs -P "${PAIRS_JOBS:-4}" -L1 bash -c 'bash "$0" --one "$1" "$2" "$3"' "$0" < <(sed "s|\$| $W|" "$W/list") > "$W/results"
same=$(grep -c '^SAME ' "$W/results"); differs=$(grep -c '^DIFFERS ' "$W/results"); skip=$(grep -c '^SKIP ' "$W/results"); unm=$(grep -c '^UNMEASURED ' "$W/results")
sort "$W/results"
echo "REALKERNEL pairs=$(wc -l < "$W/list") same=$same differs=$differs skipped_for_a_red_of_their_own=$skip unmeasured=$unm"
[ "$unm" = 0 ] && [ $((same + differs)) -gt 0 ] || { echo "REFUSE(2): pairs could not be measured"; exit 2; }
[ "$differs" = 0 ]
