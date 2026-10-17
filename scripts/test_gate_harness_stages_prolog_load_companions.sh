#!/usr/bin/env bash
# test_gate_harness_stages_prolog_load_companions.sh -- A PROLOG ENTRY'S LOADED MODULE IS STAGED BESIDE IT (the coo 2026-10-10, row
# instruments-the-harness-stages-a-prolog-companion-loaded-by-use-module-ensure-loaded-consult-or-include-ceo-1603; the ceo, CEO-1603, on
# hq_prolog's report: "the companion patterns know no Prolog use_module or ensure_loaded, so a program loading a module vendored beside
# it runs without it (puzzles farmer loads bplan.pl)"). corpus_suite_harness._copy_companions stages what an entry names into the
# isolated directory it runs in; it knew quoted names with an extension, Icon $include/open and SNOBOL4 -INCLUDE, and staged none of
# Prolog's unquoted, extension-less load forms -- 0 of 5 on this fixture before the change.
#   ARM 1  the five load forms (use_module(m1), ensure_loaded(m2), consult(m3), [m4] as a directive list, include(m5)) stage m1.pl..m5.pl
#   ARM 2  use_module(library(clpfd)) and use_module(library(lists), [append/3]) stage nothing (a system library is never a companion)
#   ARM 3  a quoted name with its extension (use_module('q.pl')) still stages, and an unquoted name with .pl (ensure_loaded(r.pl))
#   ARM 4  a name with no file beside the entry is a silent no-op, never an error (the entry's own run names the miss)
#   ARM 5  TRANSITIVE: a staged module's own use_module(deep) is staged too (the closure the other patterns already have)
# EXIT: 0 every arm holds · 1 an arm is red · 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=harness_stages_prolog_load_companions
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/src" "$T/d1" "$T/d2" "$T/d3" "$T/d4" "$T/d5"
for m in m1 m2 m3 m4 m5 q r deep mid; do printf '%s(ok).\n' "$m" > "$T/src/$m.pl"; done
printf ':- use_module(deep).\nmid(ok).\n' > "$T/src/mid.pl"
printf ':- use_module(m1).\n:- ensure_loaded(m2).\n:- consult(m3).\n:- [m4].\n:- include(m5).\nmain :- true.\n' > "$T/p1.pl"
printf ':- use_module(library(clpfd)).\n:- use_module(library(lists), [append/3]).\nmain :- true.\n' > "$T/p2.pl"
printf ":- use_module('q.pl').\n:- ensure_loaded(r.pl).\nmain :- true.\n" > "$T/p3.pl"
printf ':- use_module(nosuch).\n:- ensure_loaded(absent).\nmain :- true.\n' > "$T/p4.pl"
printf ':- use_module(mid).\nmain :- true.\n' > "$T/p5.pl"
out="$(python3 - "$HERE" "$T" <<'PY'
import sys, os, pathlib
sys.path.insert(0, sys.argv[1]); t = sys.argv[2]
import corpus_suite_harness as h
for i in range(1, 6):
    try:
        h._copy_companions(open('%s/p%d.pl' % (t, i)).read(), t + '/src', pathlib.Path('%s/d%d' % (t, i)))
        print('d%d %s' % (i, ' '.join(sorted(os.listdir('%s/d%d' % (t, i)))) or '-'))
    except Exception as e:
        print('d%d ERROR %s' % (i, type(e).__name__))
PY
)" || { echo "GATE UNPROVEN(2) [$G]: the harness could not be imported"; exit 2; }
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
got() { printf '%s\n' "$out" | sed -n "s/^$1 //p"; }
[ "$(got d1)" = "m1.pl m2.pl m3.pl m4.pl m5.pl" ] && ck ok "ARM 1 the five Prolog load forms stage m1.pl..m5.pl" || ck bad "ARM 1 staged <$(got d1)>"
[ "$(got d2)" = "-" ] && ck ok "ARM 2 library(clpfd) and library(lists) stage nothing" || ck bad "ARM 2 staged <$(got d2)>"
[ "$(got d3)" = "q.pl r.pl" ] && ck ok "ARM 3 a quoted name and an unquoted name.pl still stage" || ck bad "ARM 3 staged <$(got d3)>"
[ "$(got d4)" = "-" ] && ck ok "ARM 4 a name with no file beside the entry is a silent no-op" || ck bad "ARM 4 read <$(got d4)>"
[ "$(got d5)" = "deep.pl mid.pl" ] && ck ok "ARM 5 a staged module's own use_module is staged too" || ck bad "ARM 5 staged <$(got d5)>"
if [ "$fails" -eq 0 ]; then echo "GATE PASS(0) [$G]: $checks of $checks arms hold"; exit 0; fi
echo "GATE FAIL(1) [$G]: $fails of $checks arms red"; exit 1
