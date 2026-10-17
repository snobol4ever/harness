#!/bin/bash
# lib_donewhen.sh -- THE ONE AUTHORITY for "what is the first COMMAND WORD of a DONE-WHEN".
# hq_T 2026-09-11, on hq_S's measured false positive. Sourced by test_gate_baton_donewhen_runnable.sh and by
# s4e_msg.sh (mint and done). ⛔ FOUR COPIES OF THE OLD ONE-LINER EXISTED -- gate:108, gate:139, s4e_msg:810,
# s4e_msg:1675 -- all with the same defect, so a row refused by one was refused by all and a fix in one was a
# fix in none.
#
# ⛔⭐⭐ THE DEFECT, hq_S's own words and their own two rows (2026-09-11): the old extractor was
#   awk '{for(i=1;i<=NF;i++){if($i !~ /^[A-Za-z_][A-Za-z0-9_]*=/){print $i; exit}}}'
# -- it SPLITS ON WHITESPACE and takes the first field that is not a NAME= prefix. Feed it the ordinary shape
#   D=$(mktemp -d) && bash ../harness/scripts/test_x.sh
# and the fields are `D=$(mktemp` (skipped: it matches NAME=) and then `-d)`, which is not a command. The row
# is reported PERMANENTLY UNCLOSEABLE although it parses under bash -n and runs to rc=0. It bit
# snobol4-return-at-level-zero-crashes-instead-of-error-242 -- a row that had just been CURED -- and
# snobol4-error-243-non-name-nreturn-result-is-not-raised-where-sbl-halts.
# ⭐ THE SHAPE, which is the reusable half: THE ARM ASKED "IS THE FIRST WORD A COMMAND" AND ANSWERED IT BY
# SPLITTING ON SPACES -- a narrower question than the one it meant, the same family as $? after a pipeline and
# as `command -v icont` read as "does it exist". An instrument that answers a narrower question never says so.
# ⛔ AND THE COST LANDED ON THE ROW, NOT THE READER: hq_S worked around it by rewriting two DONE-WHENs to avoid
# a space inside a substitution. A gate that makes seats write worse criteria to please it has inverted its job.
#
# WHAT THIS DOES INSTEAD: a character scanner that respects the quoting and nesting bash respects -- '...',
# "...", `...`, $(...) to any depth, ${...} -- so an assignment prefix is consumed AS ONE WORD however many
# spaces live inside its substitution. It then skips shell operators and reserved words and returns the first
# real command word. ⛔ IT NEVER EXECUTES ANYTHING and never expands anything.
#
# ⛔⭐ AND IT REPORTS "NOT STATICALLY RESOLVABLE" RATHER THAN GUESSING. When the first command word is itself a
# substitution or a quoted string ($SCRIP, "$R/scrip", `which x`), NO static check can say whether it resolves,
# and the honest answer is neither PASS nor FAIL: donewhen_first_word prints nothing and the caller skips the
# resolution arm (bash -n has already proved the line parses). A checker that cannot measure says so -- it does
# not convict. That is the same rule the suites live under, applied to one word.
donewhen_first_word() {
    printf '%s' "$1" | awk '
    function isword(c) { return (c ~ /^[A-Za-z0-9_]$/) }
    {
        line = $0; n = length(line); i = 1
        while (i <= n) {
            c = substr(line, i, 1)
            if (c == " " || c == "\t") { i++; continue }
            # ── OPERATORS AND GROUPING: not words. `cmd1 && cmd2` must look past the &&, and a leading
            # ( or { opens a subshell/group whose first command is the one we are after.
            if (c ~ /^[;&|()!]$/ || c == "{" || c == "}") { i++; continue }
            # ── A REDIRECTION IS NOT A COMMAND, AND NEITHER IS ITS TARGET. `2>/dev/null bash x.sh` and
            # `> out bash x.sh` both run bash; an earlier draft of this scanner answered `2` and `out`,
            # which is the same class of false positive it was written to end, one token along.
            if (c == "<" || c == ">" || (c ~ /^[0-9]$/ && substr(line, i+1) ~ /^[0-9]*[<>]/)) {
                while (i <= n && substr(line, i, 1) ~ /^[0-9]$/) i++
                while (i <= n && substr(line, i, 1) ~ /^[<>&]$/) i++
                while (i <= n && (substr(line, i, 1) == " " || substr(line, i, 1) == "\t")) i++
                while (i <= n && substr(line, i, 1) !~ /^[ \t;&|()]$/) i++
                continue
            }
            # ── A WORD. Scan to the first unquoted blank or operator, tracking quotes and $( ) nesting.
            w = ""; depth = 0
            while (i <= n) {
                c = substr(line, i, 1)
                if (c == "\\" && i < n) { w = w c substr(line, i+1, 1); i += 2; continue }
                if (c == "\047") {                                   # single quotes: literal to the next one
                    w = w c; i++
                    while (i <= n) { c = substr(line, i, 1); w = w c; i++; if (c == "\047") break }
                    continue
                }
                if (c == "\"") {                                     # double quotes: honour backslash escapes
                    w = w c; i++
                    while (i <= n) {
                        c = substr(line, i, 1)
                        if (c == "\\" && i < n) { w = w c substr(line, i+1, 1); i += 2; continue }
                        w = w c; i++
                        if (c == "\"") break
                    }
                    continue
                }
                if (c == "`") {                                      # old-style command substitution
                    w = w c; i++
                    while (i <= n) { c = substr(line, i, 1); w = w c; i++; if (c == "`") break }
                    continue
                }
                if (c == "$" && i < n && (substr(line, i+1, 1) == "(" || substr(line, i+1, 1) == "{")) {
                    # ⛔ THE WHOLE BUG IN ONE BRANCH: $( ... ) and ${ ... } may contain SPACES, and the word
                    # does not end at them.  Depth-counted so $( $( ) ) nests.
                    close_c = (substr(line, i+1, 1) == "(") ? ")" : "}"
                    open_c  = substr(line, i+1, 1)
                    w = w c substr(line, i+1, 1); i += 2; depth = 1
                    while (i <= n && depth > 0) {
                        c = substr(line, i, 1)
                        if (c == "\\" && i < n) { w = w c substr(line, i+1, 1); i += 2; continue }
                        if (c == open_c) depth++
                        else if (c == close_c) depth--
                        w = w c; i++
                    }
                    continue
                }
                if (c == " " || c == "\t" || c ~ /^[;&|<>()]$/) break
                w = w c; i++
            }
            if (w == "") { i++; continue }
            # ── AN ASSIGNMENT PREFIX IS NOT THE COMMAND: NAME=..., consumed whole above.
            if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
            # ── A REDIRECTION TARGET is not a command either (2>file, >out).
            if (w ~ /^[0-9]*[<>]/) continue
            # ── RESERVED WORDS introduce a command, they are not one.
            # ── `for f in a b; do CMD` -- the loop VARIABLE and the word list are not commands either.
            # Skip to the `do`, whose own iteration then falls through to the body. An earlier draft
            # answered `f` here.
            if (w == "for" || w == "select") {
                while (i <= n) {
                    if (substr(line, i, 2) == "do" && (i+2 > n || substr(line, i+2, 1) ~ /^[ \t;&|]$/)) { i += 2; break }
                    i++
                }
                continue
            }
            # ⛔ `case` IS WHERE THIS SCANNER STOPS AND SAYS SO. Its patterns are words that are not
            # commands and its arms are separated by `)` and `;;`, and a scanner that guessed here would
            # convict a pattern. Not statically resolvable is an ANSWER; a plausible wrong word is not.
            if (w == "case") exit
            if (w == "if" || w == "then" || w == "elif" || w == "else" || w == "fi" ||
                w == "while" || w == "until" || w == "do" || w == "done" || w == "esac" ||
                w == "in" || w == "function" || w == "time" || w == "!" ||
                w == "[[" || w == "]]") continue
            print w; exit
        }
    }'
}
# ⛔ THE CALLER MUST ASK THIS BEFORE `command -v`. A word carrying an expansion or a quote cannot be resolved
# statically by anybody, and convicting it is exactly the class of false positive this file exists for.
donewhen_word_is_resolvable() {
    case "$1" in
        ''|*'$'*|*'`'*|*"'"*|*'"'*) return 1 ;;
        /*|./*|../*) [ -x "$1" ] ;;
        *) return 0 ;;
    esac
}
donewhen_selftest() {
    local f=0 p=0 got want dw
    _t() {
        dw="$1"; want="$2"
        got="$(donewhen_first_word "$dw")"
        if [ "$got" = "$want" ]; then p=$((p+1)); printf '  ok   %-52s -> %s\n' "$(printf '%.52s' "$dw")" "${got:-<not statically resolvable>}"
        else f=$((f+1)); printf '  FAIL %-52s -> %s (wanted %s)\n' "$(printf '%.52s' "$dw")" "${got:-<empty>}" "${want:-<empty>}"; fi
    }
    # ⭐ ARM 1 IS hq_S's EXACT INPUT, verbatim from their 2026-09-11 message, and it is the reason this file
    # exists. The old extractor answered `-d)` here and called two live rows PERMANENTLY UNCLOSEABLE.
    _t 'D=$(mktemp -d) && bash ../harness/scripts/test_x.sh' bash
    _t 'D=$(mktemp -d); cd "$D" && ./x' cd
    _t 'bash ../harness/scripts/test_y.sh' bash
    _t 'RT_OPT=-O0 make test' make
    _t 'A=1 B="two words" C=$(echo a b) python3 x.py' python3
    _t 'out=$(bash a.sh 2>&1); printf "%s" "$out" | grep -q x' printf
    _t '( cd x && bash y.sh )' cd
    _t '{ bash y.sh; }' bash
    _t '! grep -q x file' grep
    _t 'for f in a b; do bash $f; done' bash
    _t 'if bash a.sh; then true; fi' bash
    _t 'X=`mktemp -d` && ls "$X"' ls
    _t 'V=${HOME:-/tmp x} bash z.sh' bash
    _t '2>/dev/null bash z.sh' bash
    _t 'time bash z.sh' bash
    _t '"$SCRIP" --run x.icn' '"$SCRIP"'
    _t '$SCRIP --run x.icn' '$SCRIP'
    _t 'Run the ladder and check it passes' Run
    _t '> out bash z.sh' bash
    _t 'case $x in a) bash y.sh;; esac' ''
    _t 'for f in *.sno; do "$S" $f; done' '"$S"'
    # ⛔ AND THE RESOLVABILITY SPLIT, which is the other half of the cure: a word carrying an expansion is
    # NOT convicted, because no static check can resolve it.
    for w in '"$SCRIP"' '$SCRIP' '`which x`' "'x y'"; do
        if donewhen_word_is_resolvable "$w"; then f=$((f+1)); printf '  FAIL %-52s should NOT be statically resolvable\n' "$w"
        else p=$((p+1)); printf '  ok   %-52s correctly reported as not statically resolvable\n' "$w"; fi
    done
    for w in bash make python3; do
        if donewhen_word_is_resolvable "$w"; then p=$((p+1)); printf '  ok   %-52s is a plain literal, resolution applies\n' "$w"
        else f=$((f+1)); printf '  FAIL %-52s should be statically resolvable\n' "$w"; fi
    done
    printf 'donewhen_selftest: %d ok, %d FAIL\n' "$p" "$f"
    [ "$f" -eq 0 ]
}

# ⛔⭐⭐ THE ONE DONE-WHEN EXTRACTOR, AND IT READS THE WHOLE CRITERION (hq_T 2026-09-05, ceo rank-0 ruling on
# seat04's row s4e-msg-donewhen-truncation-false-closes-multiline-heredoc-batons; seat04 reproduced it end to end).
# It used to be `sed -n 's/^DONE-WHEN:...//p' "$b" | head -1` at THREE sites -- one physical line, discarding
# everything after it. ⛔ THAT IS A FALSE-GREEN ENGINE, NOT MERELY A TRUNCATION, and the direction is what makes it
# lethal: for the heredoc witness shape this project actively encourages ("creates its own repro at check-time
# rather than depending on this session's /tmp scratchpad"),
#     DONE-WHEN: cat > /tmp/w.sno <<'EOF'
#     <program>
#     EOF
#     out=$(scrip /tmp/w.sno); [ "$out" = want ] || exit 1; echo PASS
# the truncated text is `cat > /tmp/w.sno <<'EOF'` with no closing delimiter. bash WARNS ("here-document
# delimited by end-of-file"), treats the body as empty, writes a ZERO-BYTE file, and that cat -- the only command
# reached -- exits 0. So the whole criterion exits 0 having run NOTHING: the real check never executes, and a
# broken tree is byte-identical in verdict to a fixed one. ⭐ MEASURED CLOSURE: snobol4-pattern-primitive-as-
# function-argument-always-fails-in-callee closed DONE 2026-09-05T15:33Z through exactly this path, while the
# full untruncated text exits 1 on the same tree. 185 of 1128 live batons carry a multi-line DONE-WHEN.
# ⭐ THE CONTINUATION RULE IS THE FILE FORMAT'S OWN, not a new convention: a baton field runs to the next column-0
# field label or `## ` section -- which is exactly how GOAL: already carries paragraphs. The terminator set is the
# MEASURED label census of the live tasks tree, not a guess, and it is deliberately the STRUCTURAL labels only:
# prose labels that occur inside GOAL bodies (STEP 1:, Verified:, witness:) are NOT terminators, because a
# criterion's heredoc body is program text and must never be cut by a word that happens to end in a colon.
# Sets $_dw_backticked=1 when it stripped a markdown backtick pair, so a caller can still announce that.
# ⛔⭐ GENERALISED TO A LABEL 2026-09-20 (coo, row instruments-claim-computes-the-rows-premise-the-way-done-
# computes-its-done-when). PREMISE-WHEN is a criterion living in the SAME file format and read by the SAME rules --
# multi-line only by evidence, heredoc-aware, one matched backtick pair stripped -- so it reads through THIS
# extractor with the label as an argument. ⛔ A SECOND COPY IS THE THING BEING REFUSED HERE, and not as a style
# preference: the truncation class this function exists to cure WAS a one-line `sed` repeated at THREE sites, and
# a private premise extractor would be the fourth -- correct on the day it is written and silently divergent the
# first time this one is sharpened. ⛔ PREMISE-WHEN JOINS THE TERMINATOR SET in the same edit, which is the
# load-bearing half: without it a multi-line DONE-WHEN would SWALLOW the PREMISE-WHEN line printed under it and
# run the premise as part of the completion test. No live baton carries the field yet, so this changes no
# reading on today's tree -- it is written before the first one exists rather than after the first false green.
s4e_field_criterion_text() {   # $1 = baton path, $2 = column-0 label (DONE-WHEN | PREMISE-WHEN); prints the WHOLE criterion
    local b="$1" lbl="${2:-DONE-WHEN}" first rest line acc
    _dw_backticked=""
    first="$(sed -n "s/^${lbl}:[[:space:]]*//p" "$b" | head -1)"
    [ -n "$first" ] || return 0
    # \u26d4\u2b50\u2b50 A SECOND LABEL OF THE SAME NAME IS NOT A SECOND CRITERION, IT IS A SILENTLY DISCARDED ONE (ceo CEO-1079).
    # `head -1` above takes the FIRST and drops the rest without a word.  The coo measured 17 batons carrying the
    # PREMISE-WHEN placeholder and EIGHT carrying it BESIDE a real line, and observed that every one is harmless
    # TODAY only because the real line happens to come first -- so the day a baton is edited in the other order,
    # the row dispatches with its premise UNRUN while the file looks complete.  Measured on the live tree at this
    # landing: NINE batons carry more than one PREMISE-WHEN.  `mint` is not the door -- it already suppresses its
    # placeholder when the minted text supplies a real line -- so these were acquired by HAND EDITS after the
    # mint, which a mint-time guard could never have caught.  This is the one choke point both `claim` and `done`
    # read through, so it is where the ambiguity has to be surfaced.  It WARNS rather than REFUSES deliberately:
    # refusing would redden nine live rows for a defect none of their owners can see, which is the fleet-wide
    # cost this file spends the rest of its length avoiding.  The warning names the file and both texts so the
    # owner can delete one; when the count reaches zero this can become a refusal and the comment says so.
    { local _n; _n="$(grep -c "^${lbl}:" "$b" 2>/dev/null || echo 0)"
      if [ "${_n:-0}" -gt 1 ]; then
        printf '\u26a0 %s CARRIES %s LINES LABELLED %s AND ONLY THE FIRST IS READ -- the others are DISCARDED SILENTLY.\n' "$b" "$_n" "$lbl" >&2
        printf '  READ : %s\n' "$first" >&2
        sed -n "s/^${lbl}:[[:space:]]*//p" "$b" | tail -n +2 | while IFS= read -r _d; do printf '  DROPPED: %s\n' "$_d" >&2; done
        printf '  Delete the one you do not mean.  A criterion that exists in the file and never runs is the\n' >&2
        printf '  false-green shape this bus is built against (ceo CEO-1079).\n' >&2
      fi; }
    acc="$first"
    # ⛔⭐⭐ CONTINUE ONLY WHILE THE TEXT IS INCOMPLETE SHELL, NEVER "UNTIL THE NEXT FIELD LABEL" -- and that
    # distinction is the whole design, measured the hard way. The obvious rule (take every line to the next
    # column-0 label, the way GOAL: carries paragraphs) is WRONG HERE and dangerous in the false-green direction
    # it is trying to cure: the live convention puts PROSE ANNOTATION after a criterion -- "⛔ DONE-WHEN REWRITTEN
    # 2026-08-24 (seat04): the line above used to be prose..." -- and 121 of the 122 DONE batons whose field spans
    # lines are exactly that shape. Swallowing their annotation into `bash -c` would break rows that close
    # correctly today, to fix one that does not.
    # ⭐ THE DISCRIMINATOR IS MEASURED, not a heuristic about indentation or glyphs: bash tells you whether text is
    # FINISHED. A complete line parses clean; a heredoc opener parses rc=0 WITH a "here-document ... delimited by
    # end-of-file" warning; an unclosed quote is rc=2 "unexpected EOF while looking for matching"; and PROSE is
    # rc=2 with a DIFFERENT error ("syntax error near unexpected token"), which must NOT pull the next line in.
    # So: a complete first line IS the criterion, byte for byte as before, for every baton in the tree today.
    # ⛔ RESIDUE, STATED RATHER THAN GUESSED AT: a criterion authored as two SYNTACTICALLY COMPLETE lines is
    # indistinguishable from an annotated one in this file format, so it still runs only its first line. That is
    # not curable by reading harder -- it needs a mint-time lint requiring one line, or an explicit continuation
    # (a trailing \\, && or a heredoc), which is what every real multi-line criterion in the tree already uses.
    if s4e_donewhen_incomplete "$acc"; then
        # ⭐ MULTI-LINE MODE, ENTERED ONLY BY EVIDENCE: the first line does not finish, so the criterion is the
        # WHOLE field block -- to the next column-0 field label or `## ` section, the baton format's own rule (it
        # is how GOAL: already carries paragraphs). Taking the whole block matters and a "keep adding lines until
        # it parses" loop is NOT enough: a heredoc becomes complete at its own delimiter, and seat04's measured
        # shape puts the REAL CHECK on the lines AFTER that delimiter -- stopping at first-complete would capture
        # the file write and drop the test, which is the original false green with two extra lines in it.
        # ⛔ And if the block ends still unfinished, the incompleteness guard at both runner sites REFUSES rc=2
        # rather than running it -- so a terminator that fires inside a heredoc body fails safe, never green.
        acc="$acc
$(awk -v lbl="$lbl" '
            $0 ~ "^" lbl ":" && !seen { seen=1; next }
            seen && /^## / { exit }
            seen && /^(GOAL|LINKS|RANK|DONE-WHEN|DONE-WHEN-HISTORY|PREMISE-WHEN|PREMISE-WHEN-HISTORY|SCOPE|LEDGER|OWNER|BLOCKED-ON|FINDING|MINTED BY):/ { exit }
            seen { print }
        ' "$b")"
    fi
    # ⛔ ONE matched OUTER pair only, and never a one-sided backtick: a lone ` is either real substitution or a
    # typo, and both must fail LOUDLY rather than be silently rewritten. Normalised HERE, at the one extraction
    # point, so the vacuity probe and the real run cannot disagree about what the criterion IS.
    case "$acc" in '''`'''*'''`''') acc="${acc#\`}"; acc="${acc%\`}"; _dw_backticked=1;; esac
    printf '%s' "$acc"; }
# The two named readers. Every existing caller keeps calling s4e_donewhen_text and sees no change whatever.
s4e_donewhen_text() { s4e_field_criterion_text "$1" DONE-WHEN; }
s4e_premise_text()  { s4e_field_criterion_text "$1" PREMISE-WHEN; }
s4e_donewhen_incomplete() {   # $1 = criterion text; rc 0 = bash cannot finish reading it
    # ⛔ A TRAILING BACKSLASH (or a dangling && / || / |) IS INCOMPLETE SHELL, though `bash -n` swallows it silently (coo 2026-09-16, found by
    # CEO-786's rc rule: a two-line criterion 'test -f X \' + '&& test -f Y' ran only its first line -- `test -f X \` is a usage error, rc=2 --
    # which the old `done` mapped to red, so test_gate_s4e_donewhen_runs_the_whole_criterion's arm (A) passed for weeks on a criterion
    # whose second line never ran). The explicit continuation the format asks for must be READ as one.
    case "$(printf '%s' "${1:-}" | sed -e 's/[[:space:]]*$//')" in *\\|*'&&'|*'||'|*'|') return 0;; esac
    printf '%s' "${1:-}" | bash -n /dev/stdin 2>&1 \
      | grep -qE 'here-document.*delimited by end-of-file|unexpected EOF while looking for matching|syntax error: unexpected end of file'; }
s4e_donewhen_unterminated_heredoc() { s4e_donewhen_incomplete "${1:-}"; }
