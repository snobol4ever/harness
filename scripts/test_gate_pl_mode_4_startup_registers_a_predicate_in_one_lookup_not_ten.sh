#!/usr/bin/env bash
# test_gate_pl_mode_4_startup_registers_a_predicate_in_one_lookup_not_ten.sh -- A MODE-4 PROGRAM'S STARTUP REGISTERS EACH PREDICATE IN ONE LOOKUP.
# hq_prolog 2026-10-04, row prolog-bb-mode-4-startup-registers-a-predicate-in-one-lookup-not-ten-by-name-services-per-record
# (ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 7). The emitted main calls rt_proc_register_rec once per predicate with a 64-byte compile-time
# record; measured on zebra at c5e4896b9 that one call costs 4,080 Ir per record (five FNV hashes and a strcmp probe per record through
# rt_proc_set_fn / set_nparams / set_nformals / set_pname / set_frame_bytes / set_pinned, an snprintf of alpha$NAME and the emitter's
# std::string address book for the alpha seal, a memset of the grown table), and rt_gc_frame_maps_install_counted costs 1,189 Ir per map
# (gc_frame_map_registered is a linear scan over every map already added: quadratic in the program's size). Together ~975,000 Ir per
# mode-4 process on a 185-predicate program -- 18% of nrev's whole run, a constant every program of the suites pays.
# ARM 1: Ir inside rt_proc_register_rec per record <= 700 (one hash of the name, one probe, the fields stored from the record, the proc
# table's amortised growth). MEASURED on the cure: 590 per record on this witness (hash 115, probe 42, seed 32, the stores ~196, the
# growth's memset ~163 amortised); a second by-name lookup would add ~160 and cross the ceiling. The first draft said 400, a guess.
# ARM 2: Ir inside rt_gc_frame_maps_install_counted per map <= 60 (no scan of the maps already installed).
# The witness is a generated 200-predicate program; Ir is read with callgrind's --toggle-collect (load-immune: instructions retired).
# RED BEFORE on origin c5e4896b9: arm 1 reads ~4,000 per record, arm 2 ~1,200 per map (measured by SCRIP_BIN on that build).
set -u
GATE_NAME=test_gate_pl_mode_4_startup_registers_a_predicate_in_one_lookup_not_ten
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
command -v valgrind >/dev/null 2>&1 || refuse "no valgrind on PATH -- the gate reads instructions retired with callgrind"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
N=200
{
    for i in $(seq 1 $N); do echo "p$i(a, X) :- X = $i."; echo "p$i(b, $i)."; done
    echo "main :- p1(a, X), p$N(b, Y), Z is X + Y, write(Z), nl."
    echo ":- initialization(main)."
} > "$TMPD/w.pl"
timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "the witness did not compile: $(head -c 200 "$TMPD/err")"
gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "the witness did not link: $(grep -m1 -iE 'error' "$TMPD/err" | head -c 200)"
recs=$(grep -cE 'call\s+rt_proc_register_rec' "$TMPD/w.s"); [ "$recs" -ge "$N" ] || refuse "the mode-4 text registers $recs records for $N predicates -- the registration road changed shape; re-cut this gate"
maps=$(grep -cE 'call\s+rt_gc_frame_maps_install_counted' "$TMPD/w.s"); [ "$maps" = 1 ] || refuse "the mode-4 text installs its frame maps $maps times, not once -- re-cut this gate"
got="$(cd "$TMPD" && timeout -k 5 60 ./w.bin </dev/null 2>"$TMPD/err")"; [ "$got" = "201" ] || refuse "the witness answers [$got], not 201: $(head -c 160 "$TMPD/err")"
measure() { (cd "$TMPD" && timeout -k 5 600 valgrind --tool=callgrind --toggle-collect="$1" --callgrind-out-file="$TMPD/$1.cg" ./w.bin </dev/null >/dev/null 2>"$TMPD/$1.vg"); grep -m1 'Collected' "$TMPD/$1.vg" | awk '{print $NF}'; }
red=0
ir_reg=$(measure rt_proc_register_rec); [ -n "$ir_reg" ] || refuse "callgrind printed no Collected line for rt_proc_register_rec"
per_rec=$((ir_reg / recs))
if [ "$per_rec" -le 700 ]; then echo "  ok  arm 1: rt_proc_register_rec costs $per_rec Ir per record ($ir_reg over $recs records; ceiling 700)"
else echo "  RED arm 1: rt_proc_register_rec costs $per_rec Ir per record ($ir_reg over $recs records; ceiling 700)"; red=$((red+1)); fi
ir_maps=$(measure rt_gc_frame_maps_install_counted); [ -n "$ir_maps" ] || refuse "callgrind printed no Collected line for rt_gc_frame_maps_install_counted"
nmaps=$(awk '/^__gc_frame_maps:/{getline; sub(/.*\.quad[ \t]*/, ""); print; exit}' "$TMPD/w.s" | tr -dc '0-9'); [ -n "$nmaps" ] && [ "$nmaps" -gt 0 ] || refuse "the counted frame-map table __gc_frame_maps has no count word -- re-cut this gate"
per_map=$((ir_maps / nmaps))
if [ "$per_map" -le 60 ]; then echo "  ok  arm 2: rt_gc_frame_maps_install_counted costs $per_map Ir per map ($ir_maps over $nmaps maps; ceiling 60)"
else echo "  RED arm 2: rt_gc_frame_maps_install_counted costs $per_map Ir per map ($ir_maps over $nmaps maps; ceiling 60)"; red=$((red+1)); fi
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a mode-4 program registers each predicate in one lookup ($per_rec Ir per record) and installs its frame maps without a scan ($per_map Ir per map)"
exit 0
