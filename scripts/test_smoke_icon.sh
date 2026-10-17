#!/usr/bin/env bash
# test_smoke_icon.sh — per-frontend smoke for Icon, run in BOTH native execution modes.
#   mode 3 = --run     (in-process stackless native x86 BB blobs) — the primary mode.
#   mode 4 = --compile (standalone x86-64 asm -> assemble -> link libscrip_rt.so -> run -> compare).
# NOTE (2026-06-15): the IR-graph interpreter (mode 2 / --run) was DELETED — the harness no longer
#    invokes --run. m3 is now the primary correctness mode (it replaced the m2 oracle's build-sanity role).
#    DONE BAR: m3 AND m4 each zero silent FAIL (all 14 emit natively today; add [SMX]-REFUSED tracking here if
#    a future Icon test legitimately refuses a rung).
# Exit 0 iff mode-3 has zero FAIL AND mode-4 has zero FAIL AND m3 PASS >= $MODE3_MIN AND m4 PASS >= $MODE4_MIN.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude  DATE: 2026-05-30 (de-interp'd to 2-mode 2026-06-15)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
RT_SO="${HERE}/../../SCRIP/out/libscrip_rt.so"
MODE3_MIN="${MODE3_MIN:-1}"
MODE4_MIN="${MODE4_MIN:-0}"
P3=0; F3=0; P4=0; F4=0; N=0

icon() {
    local label="$1" expected="$2"
    local tmp; tmp=$(mktemp /tmp/icn_XXXXXX.icn)
    cat > "$tmp"
    N=$((N+1))
    local a3 a4 r3 r4
    a3=$(timeout -k 5 8 "$SCRIP" --run    "$tmp" 2>/dev/null </dev/null)
    # mode 4: --compile emits standalone x86-64 asm to stdout; assemble + link libscrip_rt.so + run.
    a4=""
    local s4 bin4
    s4=$(mktemp /tmp/icn_XXXXXX.s); bin4=$(mktemp /tmp/icn_XXXXXX.bin); rm -f "$bin4"
    if timeout -k 5 8 "$SCRIP" --compile "$tmp" >"$s4" 2>/dev/null </dev/null && [ -s "$s4" ] && [ -f "$RT_SO" ]; then
        if gcc -no-pie "$s4" -L"${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$bin4" 2>/dev/null; then
            a4=$(timeout -k 5 8 "$bin4" 2>/dev/null </dev/null)
        fi
    fi
    rm -f "$tmp" "$s4" "$bin4"
    if [ "$a3" = "$expected" ]; then r3="m3 PASS"; P3=$((P3+1)); else r3="m3 FAIL"; F3=$((F3+1)); fi
    if [ "$a4" = "$expected" ]; then r4="m4 PASS"; P4=$((P4+1)); else r4="m4 FAIL"; F4=$((F4+1)); fi
    printf "  [%s] [%s] %s\n" "$r3" "$r4" "$label"
}

echo "=== Icon smoke (mode 3 = --run, mode 4 = --compile) ==="

icon "write_str" "hello" << 'EOF'
procedure main()
  write("hello");
end
EOF

icon "write_int" "42" << 'EOF'
procedure main()
  write(42);
end
EOF

icon "arith" "5" << 'EOF'
procedure main()
  write(2 + 3);
end
EOF

icon "string_op" "abcd" << 'EOF'
procedure main()
  write("ab" || "cd");
end
EOF

# scan-nary concat (IR_SCAN_SEQUENCE): guards the mode-3 movsxd frame-source encoder (2026-07-13).
# Pre-fix, mode-3 read saved_δ from eax (movsxd reg/reg form) and printed "" while mode-4 printed
# "hell"; the box is otherwise uncovered by the corpus, which is why the divergence hid. Both modes
# must now agree on "hell" (contiguous arms: subject span == arm-value concatenation).
icon "scan_seq_concat" "hell" << 'EOF'
procedure main()
  write("hello" ? (tab(3)||tab(5)));
end
EOF

# scan-nary concat with a BACKWARD arm (item 1, 2026-07-13): tab(4) consumes [1:4]="hel", tab(2) moves
# backward and consumes [4:2]="el" -> "helel". The former subject-span value gave "h" (span [saved_δ,δ)=[0:1]);
# the box now concatenates each arm's own value slot, so non-contiguous/backward arms are correct in both modes.
icon "scan_seq_concat_backward" "helel" << 'EOF'
procedure main()
  write("hello" ? (tab(4)||tab(2)));
end
EOF

# ⛔ NO SEMICOLON BEFORE `else` -- THIS FIXTURE WAS NOT VALID ICON AND THE ORACLE SAYS SO (hq_C 2026-09-10, CEO-484).
# `if C then E; else F` is refused by Arizona icont with `"else": invalid expression`: the `;` TERMINATES the
# if-expression, so `else` starts a statement of its own and there is nothing for it to attach to. SCRIP accepted it
# until 38470889b taught the parser the four semicolons icont refuses -- so the smoke went 15/15 -> 13/15 on a
# CORRECTION, and the red was this file's own hand-written fixture, never the compiler. A smoke fixture is ours, not
# upstream, which is exactly why nothing was checking it against the oracle; under the one-oracle rule (CEO-391) a
# fixture icont refuses is not ground truth. Both cured forms were run through icont/iconx: "big" and "120", the
# expectations already written here, unchanged.
icon "if_expr" "big" << 'EOF'
procedure main()
  x := 10;
  if x > 5 then write("big") else write("small");
end
EOF

icon "every" "$(printf '1\n2\n3')" << 'EOF'
procedure main()
  every write(1 to 3);
end
EOF

icon "while" "$(printf '1\n2\n3')" << 'EOF'
procedure main()
  i := 1;
  while i <= 3 do {
    write(i);
    i := i + 1;
  };
end
EOF

icon "until" "$(printf '5\n4\n3\n2\n1')" << 'EOF'
procedure main()
  i := 5;
  until i <= 0 do {
    write(i);
    i := i - 1;
  };
end
EOF

icon "repeat_break" "$(printf '0\n1\n2')" << 'EOF'
procedure main()
  i := 0;
  repeat {
    if i >= 3 then break else write(i);
    i := i + 1;
  };
end
EOF

icon "proc_zeroarg" "42" << 'EOF'
procedure answer()
  return 42;
end
procedure main()
  write(answer());
end
EOF

icon "proc_recursion" "120" << 'EOF'
procedure fact(n)
  if n <= 1 then return 1 else return n * fact(n - 1);
end
procedure main()
  write(fact(5));
end
EOF

icon "bare_if" "done" << 'EOF'
procedure main()
  x := 2;
  if x > 5 then write("big");
  write("done");
end
EOF

# seq(i,j) with j != 1 (2026-09-04): lower_seq() computed the constant step then bailed with
# `if (by != 1) return NULL`, falling through to generic dispatch -> "Undefined function or
# operation" for ANY 2-arg seq() call, not just non-constant steps (icon-jcon-suite misc.icn's
# `seq(,4)`/`seq(10,20)` aborted the whole program mid-run). Fix routes by!=1 through IR_TO_BY
# (already used by `i to j by k`) instead of bailing. 3+7+11=21 pins start AND step both landing.
icon "seq_with_step" "21" << 'EOF'
procedure main()
  local total;
  total := 0;
  every total +:= seq(3,4) \ 3;
  write(total);
end
EOF

echo ""
echo "mode-3 (--run):      PASS=$P3 FAIL=$F3  / $N   (HARD: zero FAIL — primary native mode)"
echo "mode-4 (--compile):  PASS=$P4 FAIL=$F4  / $N   (HARD: zero FAIL; floor MODE4_MIN=$MODE4_MIN)"
[ "$F3" -eq 0 ] && [ "$F4" -eq 0 ] && [ "$P3" -ge "$MODE3_MIN" ] && [ "$P4" -ge "$MODE4_MIN" ]
