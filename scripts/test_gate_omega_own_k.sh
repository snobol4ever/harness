#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_omega_own_k.sh — U-GATE census (v1: census only, NOT pass/fail)
#
# SPEC: GOAL-SNOBOL4-BB-ALPHA.md advisory 2026-08-03e §5
# Over corpus/crosscheck/**/*.s + corpus/benchmarks/snobol4/*.s, per file:
#   (a) BOX = label ^(n[0-9]+|proc)_.*_α:  K = first sub rsp,K before next α/β/γ/ω (0 if none)
#   (b) ω-COVERAGE = fraction of K>0 boxes owning a release site:
#         - own _ω body: add rsp,K_own present inside _ω: .. next-label
#         - DRIVE_PAIR alias _β: add rsp,K_own + jmp (the ruling's own alias clause)
#   (c) ORPHAN-ADDS = add rsp,J where J matches no single carve size in this file
#         REGISTRY: add rsp,8 (alignment, until SHED-5); mov rsp,rbp restores (framed whacks)
#         ΣK FOLD: J equal to a contiguous carve-run sum → fold column, never orphan bucket
#         ⛔ MODEL THE POP YOU AUDIT (s38 lesson 2b): skip fold model → 100+ false orphans
#   (d) Output per-file + rollup + worst-10 by uncovered K>0 boxes
#   (e) rbp-op-refs column + proc_LBL__* ≤5-line check
#   NOT pass/fail in v1; never wire .s byte-identity into it.
#
# POSITIVE CONTROL LAW: hand-verified against roman.s before first run.
# DENOMINATOR LAW: always report N/M where M is the total K>0 population, not an armed subset.
#
# SCRIP HEAD at authorship: 8ec8dfa2   corpus HEAD: 0c2b0df7 (s39, ALPHA ZD-PATREF fix)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -euo pipefail

CORPUS="${CORPUS_DIR:-$S4E/corpus}"
SCRIP="${SCRIP_DIR:-$S4E/SCRIP}"
VERBOSE="${VERBOSE:-0}"

BM_DIR="$CORPUS/benchmarks/snobol4"

# ⛔⭐ crosscheck/**/*.s TEST-TREE ARTIFACTS WERE DELETED BY RULING, NOT MOVED (row
# dead-suite-path-consumer-sweep -- ".s exists only beside benchmarks and demos", RULES.md handoff
# step 4, .github 9b819998) -- there is nothing left under $CORPUS/crosscheck to find (the directory
# itself is gone). Per this row's own "s-regeneration technique" (seat14's diagnosis, not attempted
# by them): extract the .sno SOURCES by origin from the SNOBOL4 rungs and compile them fresh via
# ./scrip --compile -- "to know what the compiler emits, sweep the compiler, never the artifacts" is
# this project's own standing principle, and it is literally what this census needs anyway (a stale
# committed .s would be exactly the "never wire .s byte-identity into it" trap line 16 already warns
# against for a DIFFERENT reason). Families chosen to match test_crosscheck_all_backends.sh's own
# existing scope (its x86 section names these same four) rather than an arbitrary new selection.
CC_FAMILIES="crosscheck_patterns crosscheck_assign crosscheck_arith_new crosscheck_control_new"
CC_WORK="$(mktemp -d)"
trap 'rm -rf "$CC_WORK"' EXIT
RUNGS_LANG="${RUNGS_LANG:-snobol4}" source "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"
CC_S_FILES=()
for fam in $CC_FAMILIES; do
    while IFS= read -r origin; do
        [ -n "$origin" ] || continue
        name=$(rungs_entry_for_origin "$origin") || continue
        sno="$CC_WORK/${name}.sno"
        rungs_extract_origin "$origin" "$sno" >/dev/null 2>&1 || continue
        s="$CC_WORK/${name}.s"
        "$SCRIP/scrip" --compile "$sno" -o "$s" < /dev/null >/dev/null 2>&1 && [ -s "$s" ] && CC_S_FILES+=("$s")
    done < <(rungs_origins_of_family "$fam")
done

# ── gather .s files ──────────────────────────────────────────────────────────
mapfile -t S_FILES < <(printf '%s\n' "${CC_S_FILES[@]:-}" | sed '/^$/d' | sort; ls "$BM_DIR"/*.s 2>/dev/null | sort)
TOTAL_FILES=${#S_FILES[@]}
if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "ERROR: zero .s files -- $CC_WORK extraction+compile produced nothing AND $BM_DIR is empty" >&2
    exit 1
fi

# ── per-file census via Python ───────────────────────────────────────────────
TMPOUT=$(mktemp)
trap "rm -f $TMPOUT" EXIT

python3 - "${S_FILES[@]}" << 'PYEOF' > "$TMPOUT"
import re, sys, os
from collections import Counter, defaultdict

ALPHA_RE = re.compile(r'^(n\d+|proc)_\S+_α:')
BETA_RE  = re.compile(r'^(n\d+|proc)_\S+_β:')
OMEGA_RE = re.compile(r'^(n\d+|proc)_\S+_ω:')
LABEL_RE = re.compile(r'^(n\d+|proc)_\S+_[αβγω]:')
SUB_RSP  = re.compile(r'\bsub\s+rsp,\s*(\d+)')
ADD_RSP  = re.compile(r'\badd\s+rsp,\s*(\d+)')
MOV_RSP_RBP = re.compile(r'\bmov\s+rsp,\s*rbp\b')
RBP_REF  = re.compile(r'\brbp\b')
PROC_LBL = re.compile(r'^proc_LBL__')

files = sys.argv[1:]

# Accumulate rollup
rollup_alpha = 0
rollup_k_gt0 = 0
rollup_omega_own = 0
rollup_beta_alias = 0
rollup_no_release = 0
rollup_orphan = 0
rollup_fold = 0
rollup_rbp_refs = 0
per_file = []

for path in files:
    try:
        with open(path, 'rb') as fh:
            content = fh.read().decode('utf-8', errors='replace')
    except Exception:
        continue
    lines = content.splitlines()
    fname = os.path.basename(path)

    # ── (a) collect α→K mapping ──────────────────────────────────────────────
    alpha_k = {}        # lbl_name → K
    cur_alpha = None
    for ln in lines:
        if ALPHA_RE.match(ln):
            cur_alpha = ln.strip().rstrip(':')
            alpha_k[cur_alpha] = 0
        elif cur_alpha is not None:
            m = SUB_RSP.search(ln)
            if m:
                alpha_k[cur_alpha] = int(m.group(1))
                cur_alpha = None
            elif LABEL_RE.match(ln):
                cur_alpha = None   # no sub before next port label → K=0

    # derive base name: strip trailing _α
    def base(lbl): return re.sub(r'_α$', '', lbl)

    # ── collect β bodies ─────────────────────────────────────────────────────
    beta_body = defaultdict(list)
    cur_beta = None
    for ln in lines:
        if BETA_RE.match(ln):
            cur_beta = ln.strip().rstrip(':')
        elif cur_beta is not None:
            if LABEL_RE.match(ln):
                cur_beta = None
            else:
                beta_body[cur_beta].append(ln)

    # ── collect ω bodies ─────────────────────────────────────────────────────
    omega_body = defaultdict(list)
    cur_omega = None
    for ln in lines:
        if OMEGA_RE.match(ln):
            cur_omega = ln.strip().rstrip(':')
        elif cur_omega is not None:
            if LABEL_RE.match(ln):
                cur_omega = None
            else:
                omega_body[cur_omega].append(ln)

    # ── (b) ω-coverage ───────────────────────────────────────────────────────
    k_gt0_boxes = [(a, k) for a, k in alpha_k.items() if k > 0]
    own_omega = 0
    beta_alias = 0
    no_release = 0
    uncov_boxes = []
    for (a, k) in k_gt0_boxes:
        b = base(a)
        olbl = b + '_ω'
        blbl = b + '_β'
        has_ow = any(ADD_RSP.search(ln) for ln in omega_body.get(olbl, []))
        has_ba = any(ADD_RSP.search(ln) for ln in beta_body.get(blbl, []))
        if has_ow:
            own_omega += 1
        elif has_ba:
            beta_alias += 1
        else:
            no_release += 1
            uncov_boxes.append((a, k))

    # ── (c) orphan-adds ──────────────────────────────────────────────────────
    # single carve sizes present in this file
    carve_sizes = {k for k in alpha_k.values() if k > 0}
    # ΣK FOLD candidates: contiguous run sums of carve sizes (up to depth 10)
    fold_set = set()
    cs_list = sorted(carve_sizes)
    for start_k in cs_list:
        running = 0
        for step_k in cs_list:
            for _ in range(1, 11):   # up to 10 identical carve steps
                running += step_k
                fold_set.add(running)
            running = 0
        # Also multi-kind accumulations: just mark all pair/triple sums
    for a in cs_list:
        for b2 in cs_list:
            fold_set.add(a + b2)
            for c2 in cs_list:
                fold_set.add(a + b2 + c2)
    # Simple repeated-same-size sums
    for k in cs_list:
        for n in range(2, 20):
            fold_set.add(k * n)

    # All add rsp,J in the file
    all_adds = [int(m.group(1)) for ln in lines for m in [ADD_RSP.search(ln)] if m]
    add_cnt = Counter(all_adds)
    # classify
    orphan_cnt = 0
    fold_cnt = 0
    rbp_restore_cnt = sum(1 for ln in lines if MOV_RSP_RBP.search(ln))
    for j, cnt in add_cnt.items():
        if j == 8:            # alignment registry
            continue
        if j in carve_sizes:  # own-carve release
            continue
        if j in fold_set:
            fold_cnt += cnt
        else:
            orphan_cnt += cnt

    # ── rbp-op-refs ──────────────────────────────────────────────────────────
    rbp_refs = sum(1 for ln in lines if not ln.rstrip().endswith(':') and RBP_REF.search(ln))

    # ── proc_LBL__ ≤5-line check ─────────────────────────────────────────────
    lbl_lines = [(i, ln) for i, ln in enumerate(lines) if PROC_LBL.match(ln)]
    lbl_over5 = 0
    for li, _ in lbl_lines:
        # count non-empty lines in this LBL section until next label
        body_count = 0
        for ln2 in lines[li+1:]:
            if re.match(r'^[A-Za-z._]', ln2):
                break
            if ln2.strip():
                body_count += 1
        if body_count > 5:
            lbl_over5 += 1

    n_alpha = len(alpha_k)
    n_k_gt0 = len(k_gt0_boxes)
    cov = own_omega + beta_alias

    per_file.append({
        'fname': fname, 'path': path,
        'alpha': n_alpha, 'k_gt0': n_k_gt0,
        'own_omega': own_omega, 'beta_alias': beta_alias,
        'cov': cov, 'no_release': no_release,
        'orphan': orphan_cnt, 'fold': fold_cnt,
        'rbp_refs': rbp_refs, 'lbl_over5': lbl_over5,
        'uncov_boxes': uncov_boxes,
    })
    rollup_alpha += n_alpha
    rollup_k_gt0 += n_k_gt0
    rollup_omega_own += own_omega
    rollup_beta_alias += beta_alias
    rollup_no_release += no_release
    rollup_orphan += orphan_cnt
    rollup_fold += fold_cnt
    rollup_rbp_refs += rbp_refs

# ── output ────────────────────────────────────────────────────────────────────
print(f"U-GATE CENSUS  (v1: census only, NOT pass/fail)")
print(f"SCRIP HEAD: 8ec8dfa2   corpus: 0c2b0df7")
print(f"Files scanned: {len(per_file)}")
print()
print(f"{'FILE':<45}  {'α':>5}  {'K>0':>5}  {'cov':>5}  {'miss':>5}  {'ω%':>6}  {'orph':>5}  {'fold':>5}  {'rbp':>5}  {'LBL>5':>5}")
print("-" * 120)

for r in sorted(per_file, key=lambda x: -x['no_release'])[:20]:
    pct = 100.0 * r['cov'] / r['k_gt0'] if r['k_gt0'] > 0 else 100.0
    flag = " ◄" if r['no_release'] > 0 else ""
    print(f"{r['fname']:<45}  {r['alpha']:>5}  {r['k_gt0']:>5}  {r['cov']:>5}  {r['no_release']:>5}  {pct:>5.0f}%  {r['orphan']:>5}  {r['fold']:>5}  {r['rbp_refs']:>5}  {r['lbl_over5']:>5}{flag}")

print()
print("=" * 120)
pct_total = 100.0 * (rollup_omega_own + rollup_beta_alias) / rollup_k_gt0 if rollup_k_gt0 > 0 else 100.0
print(f"ROLLUP  {'all files':<37}  {rollup_alpha:>5}  {rollup_k_gt0:>5}  {rollup_omega_own+rollup_beta_alias:>5}  {rollup_no_release:>5}  {pct_total:>5.0f}%  {rollup_orphan:>5}  {rollup_fold:>5}  {rollup_rbp_refs:>5}")
print()
print(f"ω-cov breakdown:  own-ω={rollup_omega_own}  β-alias={rollup_beta_alias}  uncovered={rollup_no_release}")
print(f"orphan adds: {rollup_orphan}   fold (ΣK) adds: {rollup_fold}   rbp-op-refs: {rollup_rbp_refs}")
print()

# ── WATERMARK LINE ────────────────────────────────────────────────────────────
print(f"WATERMARK: ω-cov {rollup_omega_own+rollup_beta_alias}/{rollup_k_gt0} · orphan {rollup_orphan} · rbp-refs {rollup_rbp_refs}")
print()

# ── worst-10 by uncovered K>0 boxes ──────────────────────────────────────────
worst = sorted(per_file, key=lambda x: -x['no_release'])[:10]
print("WORST-10 files by uncovered K>0 boxes:")
for i, r in enumerate(worst, 1):
    pct = 100.0 * r['cov'] / r['k_gt0'] if r['k_gt0'] > 0 else 100.0
    print(f"  {i:2}. {r['fname']:<50}  miss={r['no_release']:4}  cov={pct:5.0f}%  orphan={r['orphan']:4}")
    if r['uncov_boxes']:
        samp = r['uncov_boxes'][:3]
        print(f"      sample uncov: {[(b.split('_')[0]+'…', k) for b,k in samp]}")

PYEOF

cat "$TMPOUT"
