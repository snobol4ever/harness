#!/usr/bin/env bash
# util_witness_sno_unknown_keyword_is_error_251.sh -- THE WITNESS of the unknown-keyword voice on the oracle's road (the ceo, CEO-1652): SPITBOL reads or writes an
# unknown keyword (&FOO, &ANCHOR., &ANCHOR_1, &anchor under -f) as its run-time ERROR 251, on the read and on the write alike. SCRIP carries Lon's user-declared
# & constants (ARCH-LANGUAGES.md section "SNOBOL4 -- user-declared & constants", Eurekas 1-3, 2026-08-19): with &USER_DECLARED_CONSTANTS at its default 1 every
# other &name is a one-time constant (read before its definition is error 342, the write is the definition) -- a SCRIP feature by Lon's word, outside the SPITBOL
# baseline, never a defect; with the switch at 0 the runtime takes SPITBOL's road. This witness grades that road: each shape runs under &USER_DECLARED_CONSTANTS = 0.
# GREEN (rc 0) when both modes raise 251 where sbl -bf raises 251 on every shape; RED (rc 1) while any shape differs; REFUSE (rc 2) when the oracle or the binary is missing.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null; SBL="${SBL:-$(sbl_correctness_bin 2>/dev/null || echo /home/resources/x64/bin/sbl)}"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2): no $ROOT/scrip -- make first"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(2): no SPITBOL oracle at $SBL"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
n=0; bad=0
while IFS= read -r stmt; do
    n=$((n + 1)); printf '%b\nEND\n' "$stmt" > "$T/o.sno"; printf '\t&USER_DECLARED_CONSTANTS = 0\n%b\nEND\n' "$stmt" > "$T/w.sno"
    o=$("$SBL" -bf "$T/o.sno" </dev/null 2>&1 | grep -aoE 'ERROR [0-9]+' | head -1 | tr -d 'ERRO ')
    m3=$(timeout -k 5 8 "$ROOT/scrip" "$T/w.sno" </dev/null 2>&1 | grep -aoE 'error [0-9]+' | head -1 | tr -d 'eror ')
    m4=""
    if timeout -k 5 8 "$ROOT/scrip" --compile --out="$T/w.s" "$T/w.sno" </dev/null >/dev/null 2>&1 && gcc -m64 "$T/w.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/w" 2>/dev/null; then
        m4=$(timeout -k 5 8 "$T/w" </dev/null 2>&1 | grep -aoE 'error [0-9]+' | head -1 | tr -d 'eror ')
    fi
    if [ "$o" = "$m3" ] && [ "$o" = "$m4" ]; then v="agree"; else v="DIFFER"; bad=$((bad + 1)); fi
    printf '  %-6s %-28s sbl=%-4s m3=%-4s m4=%-4s\n' "$v" "$(printf '%b' "$stmt" | tr '\t' ' ')" "${o:--}" "${m3:--}" "${m4:--}"
done <<'SHAPES'
\tOUTPUT = &FOO
\t&FOO = 1
\tOUTPUT = &ANCHOR.
\t&ANCHOR. = 1
\tOUTPUT = &ANCHOR_1
\tOUTPUT = &anchor
\t&FOO = 1\n\tOUTPUT = &FOO
SHAPES
echo "WITNESS sno-unknown-keyword-is-error-251 (user constants off): shapes=$n differ=$bad"
[ $bad -eq 0 ] && { echo "✅ GREEN: with user constants off an unknown keyword is SPITBOL's error 251 in both modes on every shape"; exit 0; }
echo "⛔ RED: $bad of $n shapes read a different error number from sbl -bf"; exit 1
