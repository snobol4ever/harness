#!/usr/bin/env bash
# AN initialization/1 GOAL MAY CONTAIN A VARIABLE (cto 2026-09-13, found while building the witness for the
# syntax-error blast-radius row -- the witness would not run, and the reason was not the witness).
#
# `:- initialization(a(_)).` does not run, does not fail and does not report: THE COMPILER ITSELF LOOPS. In
# mode 4 it emits without terminating, 2.5 MB of assembler and still growing when killed at 60s; mode 3 wires
# the same lowering in process and hangs the same way, so the program never starts. The same goal with a
# GROUND argument (`a(1)`) compiles and runs, and the same goal hoisted into a named predicate
# (`m :- a(_).` then `:- initialization(m).`) compiles and runs -- so the trigger is a VARIABLE IN THE
# DIRECTIVE'S OWN GOAL TERM, not the call, not the predicate and not the directive.
#
# ⭐ THE MECHANISM IS A MISSING PASS ON ONE OF TWO PRODUCERS, AND THAT IS WHY IT LOOKS LIKE NOTHING.
# lower_pl_stage2 builds ONE top-level goal graph from TWO lists: an ordinary directive is wrapped and then
# numbered by pl_dir_number_vars, which assigns every variable its slot; an initialization goal is appended
# to init_goals with NO numbering at all. Both lists are concatenated into the same pl_body_graph. So a
# variable arriving from the initialization path carries no slot, and the emitter never reaches a fixed
# point.
#
# ⛔ THE ORACLE IS THE DISCRIMINATOR AND THE CONSTRUCT IS ORDINARY: swipl runs the identical file and prints
# the answer. This is ISO 7.4.2.4 / 7.9 -- initialization/1 takes a GOAL, and a goal with variables is the
# normal case, not an exotic one. THE TIMEOUT IS PART OF THE GRADE: a hang is the failure mode, so every arm
# is bounded and a bounded arm that does not answer is RED, never a refusal -- the one shape where silence
# must be read as failure rather than as could-not-measure.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSE(2): ./scrip not built -- run make" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/subject.pl" <<'EOF'
a(1).
:- initialization(( a(X), write(x(X)), nl )).
:- initialization(a(_)).
:- initialization(write(tail)).
EOF
cat > "$W/control.pl" <<'EOF'
a(1).
m :- a(X), write(x(X)), nl.
:- initialization(m).
:- initialization(a(1)).
:- initialization(write(tail)).
EOF
rc=0
for m in 3 4; do
  for arm in control subject; do
    src="$W/$arm.pl"; out=""
    if [ "$m" = 3 ]; then out="$(timeout -k 5 25 ./scrip "$src" </dev/null 2>&1)"; k=$?
    else
      timeout -k 5 25 ./scrip --compile --out="$W/a.s" "$src" </dev/null >"$W/c.log" 2>&1; k=$?
      if [ "$k" = 0 ] && gcc -no-pie "$W/a.s" -Lout -lscrip_rt -Wl,-rpath,"$PWD/out" -lm -lpthread -o "$W/a.bin" >>"$W/c.log" 2>&1
      then out="$(timeout -k 5 25 "$W/a.bin" </dev/null 2>&1)"; k=$?; fi
    fi
    if [ "$k" -ge 124 ]; then verdict="TIMED OUT after 25s"; else verdict="answered"; fi
    got="$(printf '%s\n' "$out" | tr '\n' ' ')"
    ok=0; case "$got" in *"x(1)"*tail*) [ "$k" -lt 124 ] && ok=1;; esac
    if [ "$arm" = control ]; then
      [ "$ok" = 1 ] && echo "✅ m$m control: x(1) and tail, $verdict" \
        || { echo "⛔ REFUSE(2): m$m control arm $verdict out=[$got] -- the subject arm cannot speak" >&2; exit 2; }
    else
      [ "$ok" = 1 ] && echo "✅ m$m subject: a variable in the initialization goal runs, x(1) and tail" \
        || { echo "⛔ m$m subject $verdict out=[$got] -- want x(1) then tail; ISO 7.4.2.4 initialization/1 takes a GOAL"; rc=1; }
    fi
  done
done
[ "$rc" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
exit $rc
