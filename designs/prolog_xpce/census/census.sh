#!/usr/bin/env bash
# census.sh Bp|A17 -- officer_03's XPCE layer censuses for the prolog_xpce step harness (steps 5 and 8), 2026-11-16.
# SCRIP=<a scrip binary> (required); SEAT (default $S4E_SEAT); JOBS (default 6). Reads the oracle's layer in place
# (/usr/lib/swi-prolog/xpce/prolog), writes only a scratch folder under /tmp/s4e/$SEAT, removed at the end (KEEP=1 keeps it).
# Prints ONE line: "CENSUS <name> count=N ..." ; rc 0 count is 0, rc 1 count above 0, rc 2 refused (cannot measure).
#   Bp : reader errors with pce's operators supplied (mkb.py copies), each file's own, over the 286 files, scrip --dump-ast.
#   A17: one program ":- use_module(library(pce))." under scrip --run: its parse errors, plus its undefined directive and
#        initialization procedures (the 15 kernel predicates and the foreign library's own refusal excepted: step 9's),
#        plus the files of the 17 that library(pce) loads in swipl 9.0.4 (INVENTORY 3.3) whose load proof fails in SCRIP.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LAYER=/usr/lib/swi-prolog/xpce/prolog
NAME=${1:-}; SEAT=${SEAT:-${S4E_SEAT:-}}; JOBS=${JOBS:-6}
refuse() { echo "CENSUS ${NAME:-?} REFUSE(2): $*"; exit 2; }
case "$NAME" in Bp|A17) ;; *) refuse "usage: SCRIP=<scrip> census.sh Bp|A17" ;; esac
[ -n "${SCRIP:-}" ] && [ -x "$SCRIP" ] || refuse "SCRIP is not an executable scrip binary"
[ -n "$SEAT" ] || refuse "SEAT and S4E_SEAT are unset"
[ -d "$LAYER" ] || refuse "the oracle's layer $LAYER is absent"
mkdir -p "/tmp/s4e/$SEAT" && S=$(mktemp -d "/tmp/s4e/$SEAT/xpce_census.XXXXXX") || refuse "no scratch folder"
[ "${KEEP:-0}" = 1 ] || trap 'rm -rf "$S"' EXIT
t0=$(date +%s)
if [ "$NAME" = Bp ]; then
  n=$(wc -w < "$HERE/files.txt"); m=$(cd "$LAYER" && find . -name '*.pl' | wc -l)
  [ "$n" = 286 ] && [ "$m" = 286 ] || refuse "population moved: files.txt $n, the layer $m (286 expected)"
  ( cd "$HERE" && python3 -I mkb.py "$LAYER" "$S/B" ) || refuse "mkb.py failed"
  export S SCRIP
  xargs -a "$HERE/files.txt" -P "$JOBS" -I{} bash -c 'r={}; mkdir -p "$S/out/$(dirname "$r")"; ( cd "$S/B/$(dirname "$r")" && timeout -k 5 120 "$SCRIP" --dump-ast "$(basename "$r")" </dev/null >/dev/null 2>"$S/out/$r.err" ); echo "$? $r" >>"$S/rc.txt"'
  python3 -I - "$S" "$HERE/files.txt" "$(( $(date +%s) - t0 ))" <<'EOF'
import os, re, sys
S, files, secs = sys.argv[1], open(sys.argv[2]).read().split(), sys.argv[3]
rcs = dict((l.split(" ", 1)[1].strip(), int(l.split(" ", 1)[0])) for l in open(os.path.join(S, "rc.txt")))
if len(rcs) != len(files): print(f"CENSUS Bp REFUSE(2): {len(rcs)} of {len(files)} files ran"); sys.exit(2)
slow = [f for f in files if rcs[f] in (124, 137)]
if slow: print(f"CENSUS Bp REFUSE(2): {len(slow)} file(s) hit the 120 s limit, first {slow[0]}"); sys.exit(2)
n = 0; hit = set()
for f in files:
    for ln in open(os.path.join(S, "out", f + ".err"), errors="replace"):
        m = re.match(r"(\S+?):(\d+): parse error: ", ln)
        if m and os.path.basename(m.group(1)) == os.path.basename(f): n += 1; hit.add(f)
print(f"CENSUS Bp count={n} files={len(files)} erring_files={len(hit)} secs={secs}")
sys.exit(0 if n == 0 else 1)
EOF
  exit $?
fi
cat > "$S/a17.pl" <<'EOF'
:- use_module(library(pce)).
a17(pce_autoload, predicate_property(pce_autoload:do_trap_autoload(_), defined)).
a17(pce_dispatch, predicate_property(pce_dispatch:start_dispatch, defined)).
a17(pce_editor, predicate_property(editor_buttons:make_editor_recogniser(_), defined)).
a17(pce_error, predicate_property(pce_error:pce_catch_error(_, _), defined)).
a17(pce_expand, (expand_term(pce_ifhostproperty(prolog(swi), a17_loaded), X), X == a17_loaded)).
a17(pce_expansion, predicate_property(pce_expansion:feedback(_), defined)).
a17(pce_global, predicate_property(pce_global:trap_ref(_), defined)).
a17(pce_goal_expansion, predicate_property(pce_goal_expansion:super_class(_, _), defined)).
a17(pce_keybinding, predicate_property(pce_keybinding:make_key_binding_style_type, defined)).
a17(pce_pl, predicate_property(pce_host:property(_), defined)).
a17(pce_portray, predicate_property(pce_portray:atom_from_method(_, _), defined)).
a17(pce_principal, predicate_property(pce_principal:pce_uses_template(_, _), defined)).
a17(pce_realise, predicate_property(pce_realise:pce_bind_get(_, _, _, _, _, _, _, _), defined)).
a17(pce_messages, predicate_property(pce_messages:pce_message_context(_, _, _), defined)).
a17(pce_dot_pl, predicate_property(pce:set_version, defined)).
a17(swi_compatibility, predicate_property(pce_compatibility_layer:pce_info(_), defined)).
a17(swi_hooks, predicate_property(prolog:alternate_syntax(_, _, _, _), defined)).
a17_report :- forall(a17(F, G), ( catch(G, _, fail) -> format("A17_OK ~w~n", [F]) ; format("A17_MISSING ~w~n", [F]) )).
:- initialization(a17_report).
EOF
( cd "$S" && timeout -k 5 900 "$SCRIP" --run a17.pl </dev/null >"$S/a17.out" 2>"$S/a17.err" ); rc=$?
[ $rc = 124 ] || [ $rc = 137 ] && refuse "the load hit the 900 s limit"
python3 -I - "$S" "$rc" "$(( $(date +%s) - t0 ))" <<'EOF'
import re, sys
S, rc, secs = sys.argv[1], sys.argv[2], sys.argv[3]
K = {"new/2", "send/2", "get/3", "send_class/3", "get_class/4", "object/1", "object/2", "pce_open/3", "pce_init/2",
     "pce_dispatch/0", "pce_method_implementation/2", "pce_postscript_stream/1", "in_pce_thread/1", "in_pce_thread_sync2/2", "set_pce_thread/0"}
out = open(S + "/a17.out", errors="replace").read(); err = open(S + "/a17.err", errors="replace").read().split("\n")
ok = out.count("A17_OK "); miss = out.count("A17_MISSING ")
report = "ran" if ok + miss == 17 else "absent"
pe = sum(1 for l in err if re.match(r"\S+:\d+: parse error: ", l))
und = 0; kern = 0; foreign = 0
for l in err:
    if "foreign(pl2xpce)" in l or "init_failed" in l: foreign += 1; continue
    m = re.search(r"(?:directive raised|goal raised exception): error\(existence_error\(procedure,\(?([^,()]+?)\)?/(\d+)\)", l)
    if m:
        if f"{m.group(1)}/{m.group(2)}" in K: kern += 1
        else: und += 1
n = pe + und + (17 - ok)
print(f"CENSUS A17 count={n} parse_errors={pe} undefined={und} unloaded={17 - ok}/17 kernel_undefined={kern} foreign_refusals={foreign} report={report} rc={rc} secs={secs}")
sys.exit(0 if n == 0 else 1)
EOF
