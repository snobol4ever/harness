#!/usr/bin/env bash
# util_icon_ref_provenance.sh -- WHERE DID THIS PACKAGE'S REFS COME FROM?  Asked of the declared oracle, per
# program, with a printed denominator.  (hq_T, CEO-395 rule 3 + CEO-445 item 1, 2026-09-09.)
#
#     bash ../harness/scripts/util_icon_ref_provenance.sh jcon_tests
#     bash ../harness/scripts/util_icon_ref_provenance.sh arizona_tests --names
#
# ⛔ THE QUESTION IS NOT "DOES SCRIP PASS".  It is the one CEO-395 rule 3 asks one level above the board: a ref
# proves the answer has not MOVED; only its PROVENANCE says it agreed with anything else.  Icon's oracle is
# Arizona icont/iconx and nothing else (CEO-391 rule 1: one oracle per language, no compatibility switch).  So
# for every program with a ref, this runs the Arizona oracle the way the suite runner runs SCRIP -- same .dat /
# .args sidecars, same `link` modules, stdout only -- and asks whether the oracle reproduces the ref it is
# being graded against.  Three answers, and each is actionable by a different person:
#
#   ORACLE_REPRODUCES  the ref and the declared oracle agree. A red here is ours.
#   ORACLE_DIFFERS     the ref is NOT the declared oracle's output. Every verdict against it -- red OR GREEN --
#                      is a statement about a different implementation. ⭐ THE GREENS ARE THE WORSE HALF: a red
#                      gets looked at, a green against a foreign ref is a defect nobody will ever open.
#   ORACLE_REFUSES     the oracle will not compile it: OUTSIDE THE BASELINE (CEO-391 rule 2), never hidden,
#                      never silently passed, and out of the graded denominator with the oracle's own words.
#
# ⛔⭐ THE NONDETERMINISM ARM IS NOT OPTIONAL, AND A CONTROL RUN IS WHAT PROVED IT.  The first version of this
# census had no such arm, and its jcon reading (59 reproduce / 19 differ) looked damning on its own.  Running
# it against arizona_tests -- whose refs ARE upstream Arizona's, so nearly all of them must reproduce -- gave
# 81/8/1, and the 8 shared names with the jcon list (io, kwds, recent, fncs...) said plainly that some part of
# "differs" was the program, not the ref.  ⭐ A CENSUS WITH NO POSITIVE CONTROL CANNOT TELL A FINDING FROM ITS
# OWN METHOD.  So every DIFFERS candidate is re-run under the oracle a second time, and one that does not
# reproduce ITSELF is reported NONDETERMINISTIC and never counted as a provenance verdict -- the oracle cannot
# be evidence about a ref it does not agree with either.
#
# EXIT: 0 census printed · 2 REFUSED (no oracle, no package, or zero programs examined -- a runner that
# measured nothing never prints the success shape).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
GATE_NAME=util_icon_ref_provenance
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
ICONT="$(command -v icont_bin >/dev/null 2>&1 && icont_bin || echo /home/resources/icon-master/bin/icont)"
ICONX="$(command -v iconx_bin >/dev/null 2>&1 && iconx_bin || echo /home/resources/icon-master/bin/iconx)"
PKGNAME="${1:-}"; NAMES=0; [ "${2:-}" = "--names" ] && NAMES=1
[ -n "$PKGNAME" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: name a package under corpus/packages/icon/ (e.g. jcon_tests)"; exit 2; }
PK="$S4E/corpus/packages/icon/$PKGNAME"
[ -d "$PK" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no package at $PK"; exit 2; }
for b in "$ICONT" "$ICONX"; do [ -x "$b" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no Arizona oracle at $b -- a missing oracle does not blank a board, it prints a full plausible false one"; exit 2; }; done
W="$(mktemp -d "${TMPDIR:-/tmp}/icnrefprov.XXXXXX")" || exit 2; trap 'rm -rf "$W"' EXIT

repro=0; differ=0; refuse=0; nondet=0; D=""; R=""; N=""
for src in $(find "$PK" -name '*.icn' | sort); do
    n="$(basename "$src" .icn)"; d="$(dirname "$src")"; std="$d/$n.ref"
    [ -f "$std" ] || continue
    mods=""
    for m in $(sed -nE 's/^[[:space:]]*link[[:space:]]+"?([A-Za-z0-9_.-]+)"?.*$/\1/p' "$src"); do
        m="${m%.icn}"; [ -f "$d/$m.icn" ] && mods="$mods $d/$m.icn"
    done
    rd="$W/$n"; mkdir -p "$rd"; IN=/dev/null; A=()
    # ⛔ FED EXACTLY AS THE SUITE RUNNER FEEDS (test_icon_jcon_suite.sh): a `.dat` is BOTH stdin and argv[1], a
    # `.args` replaces argv, and `link`ed modules are compiled alongside -- the entry is its own manifest. A
    # census that skipped any of these would report a difference it manufactured itself.
    [ -f "$d/$n.dat" ] && { IN="$d/$n.dat"; A=("$n.dat"); cp "$d/$n.dat" "$rd/"; }
    [ -f "$d/$n.args" ] && A=($(cat "$d/$n.args"))
    if ! (cd "$rd" && timeout -k 5 60 "$ICONT" -s -o "$n.x" "$src" $mods >/dev/null 2>&1); then
        refuse=$((refuse+1)); R="$R $n"; continue
    fi
    got="$(cd "$rd" && timeout -k 5 30 "$ICONX" "$n.x" ${A[@]+"${A[@]}"} < "$IN" 2>/dev/null)"
    if [ "$got" = "$(cat "$std")" ]; then repro=$((repro+1)); continue; fi
    again="$(cd "$rd" && timeout -k 5 30 "$ICONX" "$n.x" ${A[@]+"${A[@]}"} < "$IN" 2>/dev/null)"
    if [ "$got" != "$again" ]; then nondet=$((nondet+1)); N="$N $n"
    else differ=$((differ+1)); D="$D $n"; fi
done
examined=$((repro+differ+refuse+nondet))
[ "$examined" -gt 0 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: examined ZERO programs with a ref under $PK"; exit 2; }
echo "ICON_REF_PROVENANCE package=$PKGNAME examined=$examined oracle_reproduces=$repro oracle_differs=$differ oracle_refuses=$refuse nondeterministic=$nondet"
[ "$NAMES" = 1 ] && { [ -n "$D" ] && echo "  ORACLE_DIFFERS (ref is not the declared oracle's):$D"
                      [ -n "$R" ] && echo "  ORACLE_REFUSES (outside the Arizona baseline):$R"
                      [ -n "$N" ] && echo "  NONDETERMINISTIC (oracle does not reproduce itself; no provenance verdict):$N"; }
exit 0
