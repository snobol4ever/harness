#!/usr/bin/env bash
# test_gate_icon_vendored_sources_compile_under_icont.sh -- THE SEMICOLON-FORM GATE (CEO-321 (a), rank 1,
# hq_I 2026-09-06). Lon's vendoring question, ruled by the ceo:
#
#   "the semicolon form may stand only where icont COMPILES it and REPRODUCES the .ref -- then it is
#    standard Icon in a dialect-neutral form, not a shim; a rewrite icont REFUSES is a defect."
#
# So a converted vendor source has to clear TWO bars, and this gate is two arms because ONE WOULD LIE:
#   ARM 1  icont accepts our copy.               A file icont refuses is a defect in OUR conversion.
#   ARM 2  the binary icont produced reproduces  Compiling is not running. A conversion can compile
#          the .ref we grade SCRIP against.      and still change behavior -- and then the .ref we
#                                                grade SCRIP against is OUR artifact, not the oracle's,
#                                                and every SCRIP pass over it is self-referential.
#
# ⛔ WHY BOTH, MEASURED: this sitting's repair (corpus d04e66629) took icont acceptance from 3 to 8 among
# the 12 files it touched while the SCRIP board stayed BYTE-IDENTICAL either side. Arm 1 alone would have
# called that a win and said nothing about whether the programs still DO the same thing. Arm 2 is the arm
# that can actually catch a conversion that silently changed behavior, and it is the one the ruling's
# "and reproduces the .ref" clause exists for.
#
# ⛔⛔ THIS GATE GRADES OUR VENDORING, NOT SCRIP. It never runs ./scrip. A red here means we edited a
# vendored source into something the upstream implementation no longer accepts or no longer agrees with;
# it says nothing about the compiler. Keep it that way -- a gate that mixes the two produces a red nobody
# can route to a lane.
#
# SCOPE: arizona_tests, the package whose conversion raised the question. ipl and jcon carry the same
# converted-vendor-source shape and are NOT wired here yet -- deliberately, and named rather than implied:
# wiring a package before its sidecars are settled produces a refusal whose DIAGNOSIS IS FALSE, which is
# worse than no line (this row's own do-not-wire-blind shape, endorsed CEO-321 (d)).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES: lib_oracle_flags.sh unloadable" >&2; exit 2; }
GATE="test_gate_icon_vendored_sources_compile_under_icont"
PKG="$S4E/corpus/packages/icon/arizona_tests"
[ -d "$PKG" ] || { echo "⛔ $GATE REFUSES rc=2: package missing: $PKG" >&2; exit 2; }
ICONT="$(icont_bin)" || exit 2
ICONX="$(iconx_bin)" || exit 2
TIMEOUT="${TIMEOUT:-25}"

# ⛔ EVERY RUN IS SANDBOXED. icont writes its executable beside the source, and these are TRACKED files.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/az_semicolon_gate.XXXXXX")" || { echo "⛔ mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cp -r "$PKG"/. "$WORK"/ || { echo "⛔ GATE REFUSES rc=2: could not stage the package" >&2; exit 2; }

# ── THE POPULATION IS THE GRADED ONE: every vendored source that carries a .ref. A file with no .ref has
# no second bar to clear, and inventing one would grade files the package never claimed were gradable.
mapfile -t REFS < <(find "$WORK" -name '*.ref' ! -name ALL.ref | sort)
GRADED=${#REFS[@]}
# ⛔ REFUSE ON A ZERO POPULATION rather than print the success shape over nothing (util_require_population's
# rule): "examined and clean" and "examined nothing" must never print the same string.
[ "$GRADED" -gt 0 ] || { echo "⛔ $GATE REFUSES rc=2: zero .ref refs found under $PKG -- graded nothing" >&2; exit 2; }

n_ok=0; n_refused=0; n_diverged=0; REFUSED=(); DIVERGED=()
link_names() { sed -E 's/#.*//' "$1" | grep -E '^[[:space:]]*link[[:space:]]' | sed -E 's/^[[:space:]]*link[[:space:]]+//; s/[;,"]/ /g' | tr -s ' \t' '\n' | sed '/^$/d'; }
made=""
for ref in "${REFS[@]}"; do
    for u in $made; do rm -f "$u.u1" "$u.u2"; done; made=""
    base="$(basename "$ref" .ref)"; dir="$(dirname "$ref")"; icn="$dir/$base.icn"
    [ -f "$icn" ] || continue
    # ⛔ A LINKED LIBRARY SHIPPED BESIDE THE SOURCE IS TRANSLATED FIRST (CEO-1269, hq_icon 2026-09-25): a NAME_driver links
    # its library NAME, which may link other libraries shipped beside it, and icont links ucode, never source -- so the local
    # link closure is translated in this sandbox first, exactly as each driver's ref was cut from iconx. A name with no source
    # beside it resolves from icont's own library as it always did. Without this every driver whose library links a
    # non-IPL neighbour (io_lib, lists_lib, random_lib ...) read as REFUSED by icont, which is the gate's gap, not the ref's.
    # ONLY A DRIVER'S closure: every other graded source's ref was cut linking icont's installed IPL ucode (ilib, cfuncs and
    # extlvals measurably diverge or refuse when their local namesakes are translated instead), so theirs is left as it was,
    # and a driver's translated ucode is removed before the next source is graded, so it can never shadow icont's library.
    todo=""; case "$base" in *_driver) todo="$(link_names "$icn")" ;; esac; seen=" "
    while [ -n "$todo" ]; do
        nxt=""
        for l in $todo; do
            case "$seen" in *" $l "*) continue ;; esac; seen="$seen$l "
            [ -f "$dir/$l.icn" ] && [ "$l" != "$base" ] || continue
            # a shipped PROGRAM is never a link target (the runner's LIBPATH rule, the coo's 2026-09-28 ruling): general/io.icn is an
            # Arizona test program, and cfunc.icn's `link io` means the installed IPL io -- translating the program made a second main
            grep -qE '^[[:space:]]*procedure[[:space:]]+main[[:space:]]*\(' "$dir/$l.icn" && continue
            (cd "$dir" && timeout -k 5 "$TIMEOUT" "$ICONT" -s -c "$l.icn" >/dev/null 2>&1); made="$made $dir/$l"; nxt="$nxt $(link_names "$dir/$l.icn")"
        done
        todo="$nxt"
    done
    # ARM 1 -- icont accepts our copy. -s silences informational chatter; rc is the verdict.
    cerr="$(cd "$dir" && timeout -k 5 "$TIMEOUT" "$ICONT" -s "$base.icn" 2>&1)"; crc=$?
    if [ "$crc" -ne 0 ]; then
        n_refused=$((n_refused+1))
        REFUSED+=("$base: $(printf '%s' "$cerr" | grep -E 'invalid|missing|too many|extraneous|undeclared' | head -1)")
        continue
    fi
    [ -x "$dir/$base" ] || { n_refused=$((n_refused+1)); REFUSED+=("$base: icont exited 0 but produced no executable"); continue; }
    # ARM 2 -- the oracle's own binary reproduces the ref we grade SCRIP against.
    # ⛔ The .dat stdin sidecar convention is the same one the suites and the ref-cutter use; they must
    # not disagree (RULES.md FACT RULE), so it is read here identically.
    stdin_src=/dev/null; [ -f "$dir/$base.dat" ] && stdin_src="$dir/$base.dat"
    # ⛔ RUN UNDER `iconx <stem>`, THE INVOCATION EVERY REF WAS CUT UNDER (CEO-624): &progname is a function of the
    # invocation, so `./kwds` answers `./kwds` against a ref reading `kwds` -- a divergence of the gate, not of the ref.
    # ⛔⭐ special/keyboard IS PTY-GRADED, NOT STDIN-GRADED, by the suite that owns it (test_icon_arizona_suite.sh, CEO-1354): a redirected stdin cannot supply getch() and
    # kbhit() a terminal, so the oracle's run here must go through the SAME icn_keyboard_pty_drive.py, or this arm reads a stdin run against a ref cut over a pty and cries
    # ref_diverged on every tree (the coo's loop and every seat's preflight-adjacent run read it red for a day, 2026-10-03). The driver renders the one error voice itself.
    if [ "$base" = keyboard ] && [ "${dir##*/}" = special ]; then
        got="$(cd "$dir" && timeout $((TIMEOUT+5)) python3 "$HERE/icn_keyboard_pty_drive.py" "$dir" "$TIMEOUT" -- "$ICONX" "$base" 2>&1)"; exp="$(cat "$ref")"
    else
        got="$(cd "$dir" && timeout -k 5 "$TIMEOUT" "$ICONX" "$base" < "$stdin_src" 2>&1)"; exp="$(cat "$ref")"
    fi
    # a CEO-409 mask beside the ref (env: the clock, the machine, the user) is applied to BOTH streams through the runner's own shim
    if [ -f "$dir/$base.mask" ]; then
        got="$(printf '%s' "$got" | python3 "$HERE/util_apply_ceo409_mask.py" "$ref" "$base" "$WORK/.mask_n" 2>/dev/null)" \
          && exp="$(printf '%s' "$exp" | python3 "$HERE/util_apply_ceo409_mask.py" "$ref" "$base" "$WORK/.mask_n" 2>/dev/null)" \
          || { echo "⛔ $GATE REFUSES rc=2: $base.mask could not be applied" >&2; exit 2; }
    fi
    if [ "$got" != "$exp" ]; then
        n_diverged=$((n_diverged+1)); DIVERGED+=("$base")
        continue
    fi
    n_ok=$((n_ok+1))
done

echo "-- $GATE: $GRADED graded vendored source(s) under arizona_tests, oracle icont/iconx 9.5.25a --"
echo "VENDORED_SEMICOLON_FORM_GATE graded=$GRADED ok=$n_ok icont_refused=$n_refused ref_diverged=$n_diverged"
[ "$n_refused" -eq 0 ] || { echo "⛔ ICONT REFUSES OUR COPY ($n_refused) -- a rewrite the upstream implementation rejects is a defect in our vendoring, never a dialect:"; printf '   %s\n' "${REFUSED[@]}"; }
[ "$n_diverged" -eq 0 ] || { echo "⛔ COMPILES BUT DOES NOT REPRODUCE ITS .ref ($n_diverged) -- the ref we grade SCRIP against is then OUR artifact, not the oracle's:"; printf '   %s\n' "${DIVERGED[@]}"; }
if [ "$n_refused" -eq 0 ] && [ "$n_diverged" -eq 0 ]; then
    echo "✅ GATE PASS [$GATE]: all $GRADED graded vendored sources compile under icont AND reproduce their .ref"
    exit 0
fi
echo "⛔ GATE FAIL [$GATE]: $n_refused refused by icont, $n_diverged diverged from their .ref"
exit 1
