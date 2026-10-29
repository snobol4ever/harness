#!/usr/bin/env bash
# test_gate_icn_a_closed_file_raises_212_on_read_and_213_on_write.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. close() was a no-op on &input, &output and &errout (the BID_close arm closed only idx > 2), so a program that
# closed &input went on reading it and one that closed &output went on writing it; and a closed user file made read, reads,
# !f and write FAIL QUIETLY, where Arizona iconx raises run-time error 212 (attempt to read file not open for reading) or 213
# (attempt to write file not open for writing). Found by the IcnBench loop test: rsg closes &input at the end of main, so its
# second in-process iteration is error 212 under iconx while SCRIP printed a second clean copy.
#
# WHAT IS HERE. The file slot carries a `closed` flag: close() sets it (the process's own std streams stay open underneath and
# are flushed, so the runtime's diagnostics still reach stderr), fh_alloc clears it when a slot is reused, and read, reads, !f,
# write and writes -- the by-name arms and the emitted single-argument write fast path -- raise 212/213 through core_icn_error,
# so &error converts them to failure with &errornumber set exactly as iconx does.
#
# ARMS. (1) STRUCTURE: the flag exists, close sets it, fh_alloc clears it, and the fast-path writers test it. (2) BEHAVIOUR, both
# media, graded against the LIVE oracle (icont/iconx 9.5.25a) on five witnesses: stdout byte-identical, the same exit status,
# and the same run-time error number on stderr. A witness the oracle does not run refuses the gate rather than passing it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
DP="$ROOT/src/driver/driver_private.h"; DG="$ROOT/src/driver/driver_globals.c"; BN="$ROOT/src/runtime/by_name_dispatch.c"; IO="$ROOT/src/runtime/io_format.c"
for f in "$DP" "$DG" "$BN" "$IO"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
echo "  HOLDS: a closed file raises 212 on read and 213 on write, &input/&output/&errout included, in both media, as iconx does"
fl=$(tr '\n' ' ' < "$DP" | grep -oE 'char closed;[^}]*\} fh_slot_t;' | wc -l); cl=$(( $(grep -c 's->closed=0' "$DG") == 1 && $(grep -c 'fh_slot_init(&g_fh\[i\], fp)' "$DG") == 2 ? 1 : 0 )); st=$(grep -c 'g_fh\[idx\].closed = 1;' "$BN"); fp=$(grep -c 'fh_is_closed(1)' "$IO")
if [ "$fl" = 1 ] && [ "$cl" = 1 ] && [ "$st" = 2 ] && [ "$fp" = 3 ]; then echo "  arm 1 PASS: the slot flag exists, both close roads set it (Icon's close builtin and the Raku IO::Handle close method, 8de60be25), fh_alloc clears it on reuse, the three fast-path writers test it"
else echo "  arm 1 FAIL: flag=$fl cleared_on_alloc=$cl set_by_close=$st fast_path_tests=$fp (want 1 1 2 3: the Icon close builtin and the Raku IO::Handle close method each mark the slot, ceo CEO-1627)"; RC=1; fi
printf 'a\nb\nc\n' > "$T/in.txt"
cat > "$T/w1.icn" <<'EOF'
procedure main()
   write(read(&input));
   close(&input);
   write(read(&input) | "failed");
end
EOF
cat > "$T/w2.icn" <<'EOF'
procedure main()
   local f, r;
   f := open("w2.icn") | stop("no open");
   write(image(close(f)));
   write(image(close(f)) | "close again failed");
   r := reads(f) | "reads failed";
   write(r);
end
EOF
cat > "$T/w3.icn" <<'EOF'
procedure main()
   close(&output);
   write(&errout, "after close");
   write("to closed output");
end
EOF
cat > "$T/w4.icn" <<'EOF'
procedure main()
   local f;
   f := open("w4.icn") | stop("no open");
   close(f);
   &error := -1;
   write(image(read(f)) | "read failed");
   write(&errornumber, " ", &errortext);
end
EOF
cat > "$T/w5.icn" <<'EOF'
procedure main()
   local f;
   f := open("w5.icn") | stop("no open");
   write(!f);
   close(f);
   every write(!f);
end
EOF
beh=""; bad=0
errno_of() { grep -oE '(Run-time )?error [0-9]+' "$1" | head -1 | grep -oE '[0-9]+$'; }
for w in w1 w2 w3 w4 w5; do
  inf=/dev/null; [ "$w" = w1 ] && inf="$T/in.txt"
  ( cd "$T" && "$ICONT" -s -o "$w.x" "$w.icn" ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses witness $w"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "./$w.x" <"$inf" >"$w.io" 2>"$w.ie" ); ir=$?
  [ "$ir" -le 1 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run witness $w (rc=$ir)"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" <"$inf" >"$w.3o" 2>"$w.3e" ); r3=$?
  ( cd "$T" && "$SCRIP" --compile --out="$w.s" "$w.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$w.4" "$w.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
    || { echo "⛔ GATE REFUSE(2) [$G]: witness $w does not build in mode 4"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "./$w.4" <"$inf" >"$w.4o" 2>"$w.4e" ); r4=$?
  ie="$(errno_of "$T/$w.ie")"; e3="$(errno_of "$T/$w.3e")"; e4="$(errno_of "$T/$w.4e")"
  if cmp -s "$T/$w.io" "$T/$w.3o" && cmp -s "$T/$w.io" "$T/$w.4o" && [ "$r3" = "$ir" ] && [ "$r4" = "$ir" ] && [ "$e3" = "$ie" ] && [ "$e4" = "$ie" ]; then beh="$beh $w:ok(rc=$ir${ie:+,err=$ie})"
  else beh="$beh $w:RED(iconx rc=$ir err=${ie:-none}; m3 rc=$r3 err=${e3:-none} out=$(cmp -s "$T/$w.io" "$T/$w.3o" && echo same || echo DIFF); m4 rc=$r4 err=${e4:-none} out=$(cmp -s "$T/$w.io" "$T/$w.4o" && echo same || echo DIFF))"; bad=1; fi
done
if [ "$bad" = 0 ]; then echo "  arm 2 PASS: five witnesses match the live oracle's stdout, exit status and error number in both media --$beh"
else echo "  arm 2 FAIL: a closed file does not behave as iconx's --$beh"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 2 of 2 arms hold" || echo "⛔ GATE FAIL [$G]"
exit $RC
