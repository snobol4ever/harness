#!/usr/bin/env bash
# test_gate_pas_an_unnamed_file_leaves_no_tmp_entry.sh -- a Pascal file variable with no external name is a temporary file:
# the runtime mkstemps it under /tmp and must unlink it at creation (POSIX tmpfile semantics -- the open descriptor keeps it
# alive). 513 /tmp/scrip_pas_* files sat on disk on 2026-10-01 from by_name_dispatch.c's two mkstemp sites, one per
# unnamed rewrite ever run (ceo, Lon: "find out why /tmp keeps filling and fix the root problem"). The witness rewrites,
# writes, resets and reads back an unnamed text file in BOTH modes; the gate counts /tmp/scrip_pas_* before and after and
# wants the count unchanged, and wants the program's answer, so a runtime that stopped creating the file cannot pass either.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; SCRIP="$ROOT/scrip"; RT="$ROOT/out"
[ -x "$SCRIP" ] && [ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(2): no ./scrip or out/libscrip_rt.so -- build first"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; trap 'rm -rf "$W"; exit 143' TERM; trap 'rm -rf "$W"; exit 130' INT
# ⛔ THE WITNESS IS A TYPED FILE: a text variable's rewrite never reaches the mkstemp site (measured 2026-10-01: the text
# twin passed on the pre-fix runtime), a `file of integer` does -- one /tmp/scrip_pas_* per run on the pre-fix runtime.
cat > "$W/unnamed.pas" <<'PAS'
program unnamed;
var g: file of integer; n: integer;
begin
  rewrite(g);
  write(g, 42);
  reset(g);
  read(g, n);
  writeln(n:1);
end.
PAS
count() { ls /tmp 2>/dev/null | grep -c '^scrip_pas_'; }
fail=0; ck() { if [ "$1" = ok ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; fail=$((fail+1)); fi; }
b=$(count)
out3="$(cd "$W" && timeout -k 5 20 "$SCRIP" -d4096k -s4096k unnamed.pas </dev/null 2>&1)"; rc3=$?
ck "$([ "$rc3" = 0 ] && [ "$out3" = "42" ] && echo ok || echo no)" "mode 3: the unnamed typed file is written, reset and read back (rc=$rc3, out='$out3')"
(cd "$W" && timeout -k 5 20 "$SCRIP" --compile -o unnamed.s unnamed.pas </dev/null >/dev/null 2>&1 && gcc -no-pie -o unnamed unnamed.s "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null)
out4="$(cd "$W" && timeout -k 5 20 ./unnamed </dev/null 2>&1)"; rc4=$?
ck "$([ "$rc4" = 0 ] && [ "$out4" = "42" ] && echo ok || echo no)" "mode 4: the same (rc=$rc4, out='$out4')"
a=$(count)
ck "$([ "$a" = "$b" ] && echo ok || echo no)" "/tmp/scrip_pas_* count unchanged across both runs (before=$b after=$a) -- the temporary file is unlinked at creation"
[ "$fail" = 0 ] && { echo "✅ GATE OK: an unnamed Pascal file leaves no /tmp entry"; exit 0; }
echo "⛔ GATE RED: $fail arm(s) failed"; exit 1
