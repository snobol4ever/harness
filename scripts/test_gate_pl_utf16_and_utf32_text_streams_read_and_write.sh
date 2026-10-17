#!/usr/bin/env bash
# test_gate_pl_utf16_and_utf32_text_streams_read_and_write.sh -- A PROLOG TEXT STREAM READS AND WRITES UTF-16BE/LE AND UTF-32BE/LE
# (cfo 2026-10-11, row prolog-logtalk-reads-100-percent-...-ceo-1689: Logtalk unicode/encodings lgt_unicode_open_4_read_03..09).
#
# Before this landing SCRIP's streams knew one encoding: open/4 detected only the UTF-8 BOM, its encoding(E) option refused every
# name but UTF-8, and set_prolog_flag(encoding, 'UTF-16LE') raised domain_error -- so the seven read_0x cases, each guarded by
# condition(set_encoding(...)), read UNGRADED. THE MECHANISM (src/driver/driver_globals.c fh_transcode, by_name_dispatch.c
# pl_open_leaf): a text stream whose encoding is UTF-16 or UTF-32 is wrapped in a transcoding stream (fopencookie keyed by the
# stream's slot index, never a heap pointer) that turns its code units into UTF-8 on read and back on write, so every reader and
# writer of the engine works unchanged. The encoding is, in order: a BOM open/4 detects on a read stream (UTF-32 before UTF-16,
# since FF FE 00 00 begins with FF FE), the encoding(E) option, the encoding flag (UTF-8, UTF-16BE, UTF-16LE, UTF-32BE,
# UTF-32LE). bom(false) skips detection, so the BOM is read as the code 0xFEFF.
#
# ARM 1 (the suite's own expectations): util_logtalk_grade.py --group encodings in m3 and m4 -- each case is graded against the
# expectation ISO/IEC 13211-1 and Logtalk state in the case -- floor 29 per mode (RE-PINNED 9 -> 29, cfo 2026-10-11, CEO-1695/1696:
# the 20 _03/_04 fixture cases are graded with _02 replayed first through the backend adapter, lib_logtalk_sequenced.tsv; the 20
# _01/_02 logtalk_compile/logtalk_load cases are EXCLUDED NO_ORACLE_ANSWER; measured 29/29 here and 6/29 on 1c320b13e, before the
# streams). ARM 2 (the bytes): a term written to a stream opened with encoding(E) and bom(true), in each of
# the four encodings, is byte-identical to the BOM plus the text as python3's codec encodes it, and reads back with E detected,
# in m3 and m4. FAIL-ONCE, measured on the parent 1c320b13e rebuilt: ARM 1 read m3_pass=2 m4_pass=2 (floor 9), ARM 2 every write
# raised domain_error(stream_option, encoding(E)); with the cure 9/9 graded and 4 of 4 byte-identical in both modes.
# rc=0 every arm · rc=1 a red · rc=2 REFUSAL (no build, no suite).  ~40 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_NAME=test_gate_pl_utf16_and_utf32_text_streams_read_and_write
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
SCRIP="$HERE/../../SCRIP/scrip"
RT="$HERE/../../SCRIP/out"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE/unicode/encodings" ] || refuse "no vendored suite at $SUITE"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
red=0
line="$(python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes m3,m4 --jobs 8 --group encodings 2>/dev/null | grep -m1 '^LOGTALK_ISO_BOARD ')"
[ -n "$line" ] || refuse "the grader printed no LOGTALK_ISO_BOARD line for --group encodings"
p3="$(printf '%s\n' "$line" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p')"
p4="$(printf '%s\n' "$line" | sed -n 's/.*m4_pass=\([0-9]*\).*/\1/p')"
if [ "${p3:-0}" -ge 29 ] && [ "${p4:-0}" -ge 29 ]; then echo "  ARM 1 GREEN: encodings m3_pass=$p3 m4_pass=$p4 (floor 29)"
else echo "  ARM 1 RED: encodings m3_pass=${p3:-?} m4_pass=${p4:-?} (floor 29)  $line"; red=1; fi
for pair in UTF-16BE:utf-16-be UTF-16LE:utf-16-le UTF-32BE:utf-32-be UTF-32LE:utf-32-le; do
    enc="${pair%%:*}"; codec="${pair#*:}"; w="w_${codec//-/_}"
    cat > "$D/$w.pl" <<PL
:- initialization(main).
main :- open('$w.bin', write, S, [encoding('$enc'), bom(true)]), writeq(S, f('Γειά', '🀙x')), write(S, '.'), nl(S), close(S),
    open('$w.bin', read, R, []), stream_property(R, encoding(E2)), read_term(R, T, []), close(R), writeq(E2-T), nl.
PL
    ( cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$w.s" "$w.pl" < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile of $w.pl failed"
    ( cd "$D" && gcc -m64 -no-pie "$w.s" -o "$w.exe" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" > /dev/null 2>&1 ) || refuse "mode 4 link of $w failed"
    python3 -c "import sys; sys.stdout.buffer.write(('\ufeff' + \"f('Γειά','🀙x').\n\").encode('$codec'))" > "$D/want.bin"
    for mode in m3 m4; do
        rm -f "$D/$w.bin"
        if [ "$mode" = m3 ]; then got="$(cd "$D" && timeout -k 5 20 "$SCRIP" --run "$w.pl" < /dev/null 2>&1)"
        else got="$(cd "$D" && timeout -k 5 20 "./$w.exe" < /dev/null 2>&1)"; fi
        want_line="'$enc'-f('Γειά','🀙x')"
        if [ -f "$D/$w.bin" ] && cmp -s "$D/$w.bin" "$D/want.bin" && [ "$got" = "$want_line" ]; then echo "  ARM 2 GREEN: $enc $mode bytes as $codec, read back $got"
        else echo "  ARM 2 RED: $enc $mode: out=[$got] want [$want_line]; bytes $( [ -f "$D/$w.bin" ] && od -An -tx1 "$D/$w.bin" | head -1 )"; red=1; fi
    done
done
[ "$red" = 0 ] && echo "PASS $GATE_NAME"
exit "$red"
