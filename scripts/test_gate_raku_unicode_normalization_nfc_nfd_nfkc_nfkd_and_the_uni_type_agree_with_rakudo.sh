#!/usr/bin/env bash
# test_gate_raku_unicode_normalization_nfc_nfd_nfkc_nfkd_and_the_uni_type_agree_with_rakudo.sh -- Uni.new(...), Uni.NFC / .NFD / .NFKC / .NFKD, Str.NFC / .NFD / .NFKC / .NFKD, THE .list / .elems / .Str / .gist OF THE RESULT, AND Uni ~ Uni
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the failing sampled Roast files: S15-normalization is 49 uniform files of 500 to 2943 assertions each, `ok Uni.new(...).NFC.list ~~ (...)`, every one "You failed 2000 tests of 2000").
#
# THE DEFECT, measured against Rakudo: SCRIP had no Uni type and no normalization forms: `Uni.new(0x1E0A, 0x0323)` produced nothing and `.NFC` was an undefined method, so S15-normalization/nfc-0.t .. nfkd-10.t, the four -sanity files and nfc-concat.t (49 files, over 70 000 assertions) failed wholesale; the four S15-nfg/mass-roundtrip-*.t files, which round-trip strings through the same forms, failed with them.
# THE CURE: (../harness/scripts/util_gen_unicode_norm_tables.py -> src/runtime/rk_unicode_norm_tables.inc) the decomposition and composition data are GENERATED from the Unicode 17.0.0 UnicodeData.txt (the version the Roast files are generated from): canonical combining classes as ranges, canonical and compatibility decompositions, and the primary composites that survive the exclusions
# (the explicit exclusions come from DerivedNormalizationProps.txt 15.1, every other exclusion is computed -- a singleton, a decomposition beginning with a non-starter, a non-starter -- and the computation is checked against the whole 15.1 list before anything is written); the generator also runs its own normalizer over every code point both versions assign and
# 60 000 random sequences and compares it with Python's unicodedata.normalize (1.38 million comparisons, 0 differences); (by_name_dispatch.c rk_un_normalize) full decomposition (Hangul algorithmic), canonical ordering of each run of non-starters, and the standard canonical composition with blocking; the objects are typed data (Uni, NFC, NFD, NFKC, NFKD, one field of code points) created by `Uni.new`
# (obj_new) and by the normalization methods on a Uni or a Str; `.list` answers the code points as a list, `.elems` / `.codes` their count, `.Str` the string, `.gist` / `.raku` the `NFC:0x<1E0C 0307>` form, and a Uni stringifies as its code points so `Uni.new(...) ~ Uni.new(...)` is a string.
# THE WITNESS is cut by the INSTALLED Rakudo (2022.12), which predates Unicode 17: its tables lack a few newer characters (U+1DFA, U+08D0 as non-starters, U+113C8 as a decomposable), so two of 70 sampled inputs were dropped from the witness (the Roast files, generated from Unicode 17.0.0, are the stronger evidence: all 49 pass here). It is graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# NOT HERE (own rows, measured): Str is not NFG (graphemes): .chars / .comb on combining sequences, S15-nfg/{case-change,cgj,concatenation,GraphemeBreakTest-*,mass-equality,many-combiners}.t, `Uni` as a lazy Buf, `.NFC` on a Buf, Str.codes / .ords on a normalized Str, `Uni.new` from a string.
# FAILED ONCE, measured on SCRIP 1cec3f1aa before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_unicode_normalization_nfc_nfd_nfkc_nfkd_and_the_uni_type_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_unicode_normalization_nfc_nfd_nfkc_nfkd_and_the_uni_type_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
sub show(*@cps) {
    my $u = Uni.new(|@cps);
    say $u.elems, ' ', $u.NFC.list.join(','), ' | ', $u.NFD.list.join(','), ' | ', $u.NFKC.list.join(','), ' | ', $u.NFKD.list.join(',');
}
show(0xC980);
show(0xD723);
show(0xCB30);
show(0xC96E);
show(0xD08A);
show(0xFC6F);
show(0x2F942);
show(0x2F8A0);
show(0xD110);
show(0xCC78);
show(0x2F8D);
show(0x1D47E);
show(0xC8C4, 0x0334, 0x11AE);
show(0xB697);
show(0x1F129);
show(0x1D412);
show(0xD476);
show(0x0061, 0x11368, 0x0315, 0x0300, 0x05AE, 0x0062);
show(0xFD89);
show(0xC25D);
show(0xC994);
show(0x1FAA);
show(0x0061, 0x0315, 0x0300, 0x05AE, 0x20DB, 0x0062);
show(0xD326);
show(0x00F2);
show(0x00AF);
show(0x2F94C);
show(0xAEC9);
show(0xFE69);
show(0x0061, 0x05B0, 0x094D, 0x3099, 0xAAF6, 0x0062);
show(0xCAF8);
show(0xB97E);
show(0xC800);
show(0xFCE4);
show(0x2F9EA);
show(0xD1F9);
show(0xADBD);
show(0xB56A);
show(0xCF85);
show(0x0061, 0x0315, 0x0300, 0x05AE, 0x073D, 0x0062);
show(0xCA22);
show(0xB363);
show(0xC3B7);
show(0xD60E);
show(0x1105, 0x0334, 0x116D);
show(0xB051);
show(0xB819);
show(0xAD3A);
show(0xD130);
show(0xB4C5);
show(0x0061, 0x05B0, 0x094D, 0x3099, 0x1B44, 0x0062);
show(0x01C6);
show(0xD791);
show(0x1D63E);
show(0xC2E8);
show(0x1D63A);
show(0xB501);
show(0xC124);
show(0x0144);
show(0x0061, 0x0315, 0x0300, 0x05AE, 0xA8E6, 0x0062);
show(0x0061, 0x0302, 0x0315, 0x0300, 0x05AE, 0x0062);
show(0x333D);
show(0x32C8);
show(0x0061, 0x1E011, 0x0315, 0x0300, 0x05AE, 0x0062);
show(0xCBBD);
show(0xBFBD);
show(0xC286);
show(0xC55D);
show(0xAC00);
show(0x1100, 0x1161, 0x11A8);
show(0xD7A3);
show(0x1100, 0xAC00, 0x11A8);
show(0x00C5);
show(0x212B);
show(0xFB01);
show(0x2460);
show(0x1E9B, 0x0323);
show(0xFDFA);
show(0x0041, 0x030A);
show();
say "a\x[0301]".NFC.list.join(',');
say "a\x[0301]".NFD.list.join(',');
say "\x[FB01]".NFKC.list.join(',');
say "\x[FB01]".NFKD.list.join(',');
say "ab".NFC.list.join(',');
say Uni.new(0x41, 0x42).Str;
say (Uni.new(0x41, 0x30A) ~ Uni.new(0x42)).NFC.list.join(',');
say Uni.new(0x1E0A, 0x0323).NFC.list ~~ (0x1E0C, 0x0307);
say Uni.new(0x1E0A, 0x0323).NFD.list ~~ (0x44, 0x323, 0x307);
say Uni.new(0x41).NFC.WHAT;
say Uni.new(0x41).WHAT;
say Uni.new(1, 2, 3).elems;
EOF
cat > "$W/w.ref" <<'EOF'
1 51584 | 4364,4466,4539 | 51584 | 4364,4466,4539
1 55075 | 4370,4465,4530 | 55075 | 4370,4465,4530
1 52016 | 4365,4461,4523 | 52016 | 4365,4461,4523
1 51566 | 4364,4466,4521 | 51566 | 4364,4466,4521
1 53386 | 4367,4468,4521 | 53386 | 4367,4468,4521
1 64623 | 64623 | 1576,1610 | 1576,1610
1 151794 | 151794 | 151794 | 151794
1 24705 | 24705 | 24705 | 24705
1 53520 | 4368,4451,4543 | 53520 | 4368,4451,4543
1 52344 | 4366,4451,4543 | 52344 | 4366,4451,4543
1 12173 | 12173 | 34411 | 34411
1 119934 | 119934 | 87 | 87
3 51396,820,4526 | 4364,4460,820,4526 | 51396,820,4526 | 4364,4460,820,4526
1 46743 | 4356,4461,4542 | 46743 | 4356,4461,4542
1 127273 | 127273 | 40,90,41 | 40,90,41
1 119826 | 119826 | 83 | 83
1 54390 | 4369,4461,4545 | 54390 | 4369,4461,4545
6 97,1454,70504,768,789,98 | 97,1454,70504,768,789,98 | 97,1454,70504,768,789,98 | 97,1454,70504,768,789,98
1 64905 | 64905 | 1605,1581,1580 | 1605,1581,1580
1 49757 | 4361,4464,4532 | 49757 | 4361,4464,4532
1 51604 | 4364,4467,4531 | 51604 | 4364,4467,4531
1 8106 | 937,787,768,837 | 8106 | 937,787,768,837
6 224,1454,8411,789,98 | 97,1454,768,8411,789,98 | 224,1454,8411,789,98 | 97,1454,768,8411,789,98
1 54054 | 4369,4449,4545 | 54054 | 4369,4449,4545
1 242 | 111,768 | 242 | 111,768
1 175 | 175 | 32,772 | 32,772
1 16534 | 16534 | 16534 | 16534
1 44745 | 4353,4453,4532 | 44745 | 4353,4453,4532
1 65129 | 65129 | 36 | 36
6 97,12441,2381,43766,1456,98 | 97,12441,2381,43766,1456,98 | 97,12441,2381,43766,1456,98 | 97,12441,2381,43766,1456,98
1 51960 | 4365,4459,4523 | 51960 | 4365,4459,4523
1 47486 | 4357,4467,4529 | 47486 | 4357,4467,4529
1 51200 | 4364,4453 | 51200 | 4364,4453
1 64740 | 64740 | 1578,1607 | 1578,1607
1 37500 | 37500 | 37500 | 37500
1 53753 | 4368,4460,4524 | 53753 | 4368,4460,4524
1 44477 | 4352,4464,4544 | 44477 | 4352,4464,4544
1 46442 | 4356,4451,4521 | 46442 | 4356,4451,4521
1 53125 | 4367,4458,4540 | 53125 | 4367,4458,4540
6 224,1454,1853,789,98 | 97,1454,768,1853,789,98 | 224,1454,1853,789,98 | 97,1454,768,1853,789,98
1 51746 | 4365,4451,4533 | 51746 | 4365,4451,4533
1 45923 | 4355,4453,4534 | 45923 | 4355,4453,4534
1 50103 | 4362,4455,4542 | 50103 | 4362,4455,4542
1 54798 | 4370,4455,4533 | 54798 | 4370,4455,4533
3 4357,820,4461 | 4357,820,4461 | 4357,820,4461 | 4357,820,4461
1 45137 | 4353,4467,4532 | 45137 | 4353,4467,4532
1 47129 | 4357,4454,4536 | 47129 | 4357,4454,4536
1 44346 | 4352,4460,4525 | 44346 | 4352,4460,4525
1 53552 | 4368,4453 | 53552 | 4368,4453
1 46277 | 4355,4466,4524 | 46277 | 4355,4466,4524
6 97,12441,2381,6980,1456,98 | 97,12441,2381,6980,1456,98 | 97,12441,2381,6980,1456,98 | 97,12441,2381,6980,1456,98
1 454 | 454 | 100,382 | 100,122,780
1 55185 | 4370,4469,4528 | 55185 | 4370,4469,4528
1 120382 | 120382 | 67 | 67
1 49896 | 4361,4469,4531 | 49896 | 4361,4469,4531
1 120378 | 120378 | 121 | 121
1 46337 | 4355,4468,4528 | 46337 | 4355,4468,4528
1 49444 | 4361,4453,4527 | 49444 | 4361,4453,4527
1 324 | 110,769 | 324 | 110,769
6 224,1454,43238,789,98 | 97,1454,768,43238,789,98 | 224,1454,43238,789,98 | 97,1454,768,43238,789,98
6 7847,1454,789,98 | 97,1454,770,768,789,98 | 7847,1454,789,98 | 97,1454,770,768,789,98
1 13117 | 13117 | 12509,12452,12531,12488 | 12507,12442,12452,12531,12488
1 13000 | 13000 | 57,26376 | 57,26376
6 97,1454,122897,768,789,98 | 97,1454,122897,768,789,98 | 97,1454,122897,768,789,98 | 97,1454,122897,768,789,98
1 52157 | 4365,4466,4524 | 52157 | 4365,4466,4524
1 49085 | 4360,4461,4532 | 49085 | 4360,4461,4532
1 49798 | 4361,4465,4545 | 49798 | 4361,4465,4545
1 50525 | 4363,4449,4544 | 50525 | 4363,4449,4544
1 44032 | 4352,4449 | 44032 | 4352,4449
3 44033 | 4352,4449,4520 | 44033 | 4352,4449,4520
1 55203 | 4370,4469,4546 | 55203 | 4370,4469,4546
3 4352,44033 | 4352,4352,4449,4520 | 4352,44033 | 4352,4352,4449,4520
1 197 | 65,778 | 197 | 65,778
1 197 | 65,778 | 197 | 65,778
1 64257 | 64257 | 102,105 | 102,105
1 9312 | 9312 | 49 | 49
2 7835,803 | 383,803,775 | 7785 | 115,803,775
1 65018 | 65018 | 1589,1604,1609,32,1575,1604,1604,1607,32,1593,1604,1610,1607,32,1608,1587,1604,1605 | 1589,1604,1609,32,1575,1604,1604,1607,32,1593,1604,1610,1607,32,1608,1587,1604,1605
2 197 | 65,778 | 197 | 65,778
0  |  |  | 
225
97,769
102,105
102,105
97,98
AB
197,66
True
True
(NFC)
(Uni)
3
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a Unicode normalization result that disagrees with Rakudo"
