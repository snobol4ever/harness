#!/usr/bin/env bash
# test_gate_pas_paren_star_conditional_directives_act_as_the_brace_form.sh -- (*$IFDEF X*), (*$IFNDEF X*), (*$ELSE*), (*$ENDIF*) and
# (*$DEFINE X*) act exactly as their brace forms do, as fpc reads them (-Miso included), and a plain (* comment *) inside a skipped
# branch stays a comment.
#
# MEASURED 2026-10-14 by hq_pascal on hq_snocone's ask (paren-star-directives-are-comments-to-the-c-lexer-and-directives-to-fpc):
# pascal.l recognised the conditional directives only after "{$", so (*$IFDEF PP*) ... (*$ENDIF*) lexed as comments and the C tree
# kept both branches -- the P4 compiler (packages/pascal/pcom.pas, ppp.pas) differed from fpc and from bootstrap/parser_pascal.sc.
# THE CURE: two rules, in INITIAL and in the SKIPC state (ahead of SKIPC's generic paren comment), match "(*$" directive "*)" and
# hand pascal_cond the brace spelling through pascal_cond_paren. pascal.lex.c regenerated with the pinned flex 2.6.4. The P4
# self-host (test_pascal_p4_selfhost.sh) reads SELFHOST OK after it.
#
# ARMS: parenstar against fpc -Miso, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red (both branches kept).
# FAIL_ONCE=1 corrupts it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/parenstar.pas" <<'PAS'
program parenstar(output);
(*$DEFINE ALPHA*)
var i: integer;
begin
  i := 0;
  (*$IFDEF ALPHA*) i := i + 1; (*$ENDIF*)
  (*$IFDEF BETA*) i := i + 10; (* a comment inside *) (*$ELSE*) i := i + 100; (*$ENDIF*)
  (*$IFNDEF BETA*) i := i + 1000; (*$ENDIF*)
  {$IFDEF ALPHA} i := i + 10000; {$ENDIF}
  writeln(i)
end.
PAS
for pm in "parenstar -Miso"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: paren-star conditional directives act as the brace form, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
