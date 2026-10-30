#!/usr/bin/env bash
# test_gate_zeta_layout_check_negative_controls_red.sh -- THE LAYOUT CHECKER CAN FAIL (DESIGN-PLAN zeta-layout step 1; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH 5; CEO-2019).
# harness/scripts/util_zeta_layout_check.py reads a program's mode-4 text against ./scrip --dump-plan. A checker that reads 0 proves nothing until it is shown to read
# more on a corrupted input, so each arm CORRUPTS A COPY OF THE CHECKER'S OWN INPUT (never a line of SCRIP's src, CEO-1680: a witness shown red against a corrupted
# reference) and demands that exactly the class the corruption belongs to rises over the clean reading:
#   CARVE         the plan's K for one lit_integer row made 48 (the box still carves 16)
#   EXCURSION     a push and a pop split by a conditional jump, planted in a lit_integer box
#   EDGE          the pop removed from a statement_end box's exit jump, so it lands deeper than the next box's entry
#   SITE          a rule-0 GC site record's depth word raised by 8
#   SPILL-PAIR    a push and its balancing pop planted on the straight run to a statement_end box's exit jump read SPILL-PAIR (and no EXCURSION); a lone push there (a
#                 call frame before the transfer) reads neither
#   RETAINING-EDGE the retaining edges print as lines, equal to the summary's count, and are NOT in mismatches
#   RULE5         a rule-0 GC site record whose rule byte is made 5 reads RULE5 (the chain stops at it), in mismatches
#   SITE rule 6   a rule-6 site's depth raised by 8 reads SITE (graded against its owning enter's row); a rule-1 site's depth raised by 8 (zl07) reads SITE
#   SITE-UNGRADED / SITE-HOP / SITE-UNEXERCISED on zl08: each rule the program emits prints the line its class owns with the summary's count, and every rule it does not emit
#                 prints UNEXERCISED; a nonzero GC_SITE_EXT byte planted in a record prints SITE-UNGRADED ext=nonzero
#   TRANSFER-POP  zl02's deferred goto read as it is (it leaks), then the CURE applied (the owed pop added before each jmp rax) reads fewer, then a WRONG pop still reads
#   ZSM           the instrument's own balanced push/pop around rt_zdp_ev (SCRIP_ZSM=1 SCRIP_ZSM_ALL=1) adds no EXCURSION and is counted as skipped
#   ALIGN         a plan with its last graph cut off
#   rc 2          an unreadable input prints no mismatches= line
# rc 0 every arm holds · rc 1 an arm failed · rc 2 cannot measure (no scrip, no witness, a witness that does not compile).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
WD="$HERE/../../corpus/tests/shared/zeta_layout"
CHK="$HERE/util_zeta_layout_check.py"
NAME=zeta_layout_check_negative_controls_red
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -r "$CHK" ] || refuse "no checker at $CHK"
for w in zl01_sno_captures_eval zl02_sno_setexit_code; do [ -r "$WD/$w.sno" ] || refuse "no witness $WD/$w.sno"; done
[ -r "$WD/zl07_pas_records_lists.pas" ] || refuse "no witness $WD/zl07_pas_records_lists.pas"
[ -r "$WD/zl08_rk_lists_hashes.raku" ] || refuse "no witness $WD/zl08_rk_lists_hashes.raku"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
for w in zl01_sno_captures_eval zl02_sno_setexit_code; do
    mkdir -p "$TD/$w"
    ( cd "$TD/$w" && timeout -k 5 120 "$SCRIP" --compile --out="$TD/$w/run.s" "$WD/$w.sno" < /dev/null > /dev/null 2> compile.err ) || refuse "$w did not compile in mode 4: $(head -c 200 "$TD/$w/compile.err")"
    ( cd "$TD/$w" && timeout -k 5 120 "$SCRIP" --dump-plan "$WD/$w.sno" < /dev/null > "$TD/$w/plan.txt" 2> plan.err ) || refuse "$w --dump-plan failed: $(head -c 200 "$TD/$w/plan.err")"
done
mkdir -p "$TD/zl07_pas_records_lists"
( cd "$TD/zl07_pas_records_lists" && timeout -k 5 120 "$SCRIP" --compile --out="$TD/zl07_pas_records_lists/run.s" "$WD/zl07_pas_records_lists.pas" < /dev/null > /dev/null 2> compile.err \
    && timeout -k 5 120 "$SCRIP" --dump-plan "$WD/zl07_pas_records_lists.pas" < /dev/null > "$TD/zl07_pas_records_lists/plan.txt" 2> plan.err ) || refuse "zl07 did not compile in mode 4"
mkdir -p "$TD/zl08_rk_lists_hashes"
( cd "$TD/zl08_rk_lists_hashes" && timeout -k 5 120 "$SCRIP" --compile --out="$TD/zl08_rk_lists_hashes/run.s" "$WD/zl08_rk_lists_hashes.raku" < /dev/null > /dev/null 2> compile.err \
    && timeout -k 5 120 "$SCRIP" --dump-plan "$WD/zl08_rk_lists_hashes.raku" < /dev/null > "$TD/zl08_rk_lists_hashes/plan.txt" 2> plan.err ) || refuse "zl08 did not compile in mode 4"
mkdir -p "$TD/zsm"
( cd "$TD/zsm" && SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 timeout -k 5 120 "$SCRIP" --compile --out="$TD/zsm/run.s" "$WD/zl01_sno_captures_eval.sno" < /dev/null > /dev/null 2> compile.err \
    && SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 timeout -k 5 120 "$SCRIP" --dump-plan "$WD/zl01_sno_captures_eval.sno" < /dev/null > "$TD/zsm/plan.txt" 2> plan.err ) || refuse "zl01 did not compile under SCRIP_ZSM=1"
python3 -I - "$CHK" "$TD" <<'PY'
import os, re, subprocess, sys
CHK, TD = sys.argv[1], sys.argv[2]
NAME = 'zeta_layout_check_negative_controls_red'
graded, fails = 0, 0


def run(asm, plan):
    r = subprocess.run([sys.executable, '-I', CHK, '--asm', asm, '--plan', plan], capture_output=True, text=True)
    last = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ''
    c = {k: int(v) for k, v in re.findall(r'([A-Za-z0-9-]+)=(\d+)', last)}
    return r, c


def grade(label, ok, detail=''):
    global graded, fails
    graded += 1
    if ok:
        print('  ok   ' + label)
    else:
        fails += 1
        print('  ⛔ FAIL ' + label + (': ' + detail if detail else ''))


MISMATCH = ('EXCURSION', 'SPILL-PAIR', 'CARVE', 'EDGE', 'TRANSFER-POP', 'SITE', 'RULE5', 'ALIGN')


def rises(label, clean, got, cls):
    others = [k for k in MISMATCH if k != cls and got.get(k, 0) < clean.get(k, 0)]
    grade(label, got.get(cls, 0) > clean.get(cls, 0), '%s %d -> %d' % (cls, clean.get(cls, 0), got.get(cls, 0)))
    grade(label + ' (no other class fell)', not others, 'fell: %s' % others)


w1, w2 = TD + '/zl01_sno_captures_eval', TD + '/zl02_sno_setexit_code'
r, clean = run(w1 + '/run.s', w1 + '/plan.txt')
grade('clean zl01 reads, last line carries mismatches=', 'mismatches' in clean and r.returncode in (0, 1), r.stderr[:200])
grade('clean zl01 baseline holds every class the controls need (EXCURSION, CARVE, SITE in the text, so the controls compare against a real reading)', all(k in clean for k in ('EXCURSION', 'CARVE', 'EDGE', 'SITE')))
asm = open(w1 + '/run.s', encoding='utf-8').read().split('\n')
plan = open(w1 + '/plan.txt', encoding='utf-8').read().split('\n')


def write(name, lines):
    p = TD + '/' + name
    open(p, 'w', encoding='utf-8').write('\n'.join(lines))
    return p


i = next((k for k, l in enumerate(plan) if l.startswith('PLAN graph=g0')), None)
j = next((k for k in range(i or 0, len(plan)) if plan[k].startswith('PLAN_ROW') and 'kind=IR_LIT_INTEGER ' in plan[k] and plan[k].split()[7] == '1'), None)
if i is None or j is None:
    print('GATE REFUSE(2) [%s]: no armed IR_LIT_INTEGER row in zl01 g0 -- the witness drifted' % NAME)
    sys.exit(2)
t = plan[j].split()
t[6] = '48'
p2 = plan[:]
p2[j] = ' '.join(t)
r, got = run(w1 + '/run.s', write('plan_k.txt', p2))
rises('CARVE: K of one lit_integer row made 48 reads CARVE', clean, got, 'CARVE')

k = next((n for n, l in enumerate(asm) if re.match(r'^n\d+_lit_integer_α:\s+sub\s+rsp, 16\s*$', l)), None)
if k is None:
    print('GATE REFUSE(2) [%s]: no lit_integer alpha carve in zl01 -- the witness drifted' % NAME)
    sys.exit(2)
a2 = asm[:k + 1] + ['  push rbx', '  test rbx, rbx', '  je 7f', '  pop rbx', '7:'] + asm[k + 1:]
r, got = run(write('run_x.s', a2), w1 + '/plan.txt')
rises('EXCURSION: a push and a pop split by a conditional jump, planted in a lit_integer box, read EXCURSION', clean, got, 'EXCURSION')
grade('EXCURSION: exactly the two planted instructions', got.get('EXCURSION', 0) - clean.get('EXCURSION', 0) == 2, '%d -> %d' % (clean.get('EXCURSION', 0), got.get('EXCURSION', 0)))

k = next((n for n, l in enumerate(asm) if re.match(r'^n\d+_statement_end_α:\s+add\s+rsp,\s*\d+;\s+jmp\s+n\d+_\w+_α\s*$', l)), None)
if k is None:
    print('GATE REFUSE(2) [%s]: no statement_end exit pop in zl01 -- the witness drifted' % NAME)
    sys.exit(2)
a2 = asm[:]
a2[k] = re.sub(r'add\s+rsp,\s*\d+;', '', a2[k])
r, got = run(write('run_e.s', a2), w1 + '/plan.txt')
rises('EDGE: the pop removed from a statement_end exit jump reads EDGE', clean, got, 'EDGE')

k = next((n for n, l in enumerate(asm) if re.match(r'^\s+\.quad\s+\.Lgcsite_\S+-\.Lgccode_\S+\s*$', l)), None)
w = int(asm[k + 1].split()[1]) if k is not None else -1
if k is None or ((w >> 16) & 255) != 0:
    print('GATE REFUSE(2) [%s]: the first GC site entry of zl01 is not a rule-0 record -- the witness drifted' % NAME)
    sys.exit(2)
a2 = asm[:]
a2[k + 1] = re.sub(r'\d+\s*$', str(w + (8 << 32)), a2[k + 1])
r, got = run(write('run_s.s', a2), w1 + '/plan.txt')
rises('SITE: the first rule-0 site record raised by 8 bytes reads SITE', clean, got, 'SITE')

k = next((n for n, l in enumerate(asm) if re.match(r'^n\d+_statement_end_α:\s+add\s+rsp,\s*\d+;\s+jmp\s+n\d+_\w+_α\s*$', l)), None)
if k is None:
    print('GATE REFUSE(2) [%s]: no statement_end exit pop in zl01 -- the witness drifted' % NAME)
    sys.exit(2)
a2 = asm[:]
a2[k] = re.sub(r'(α:\s+)(add\s+rsp)', r'\1push rbx; pop rbx; \2', a2[k])
r, got = run(write('run_p.s', a2), w1 + '/plan.txt')
rises('SPILL-PAIR: a push and its pop planted on the straight run to an exit jump read SPILL-PAIR', clean, got, 'SPILL-PAIR')
grade('SPILL-PAIR: exactly one pair, and the two instructions add no EXCURSION (%d vs %d)' % (got.get('EXCURSION', -1), clean.get('EXCURSION', -2)),
      got.get('SPILL-PAIR', 0) - clean.get('SPILL-PAIR', 0) == 1 and got.get('EXCURSION', -1) == clean.get('EXCURSION', -2))
grade('SPILL-PAIR: the clean reading holds the exit pops (and a pop alone is not a pair)', clean.get('SPILL-PAIR', -1) == 0)
a2 = asm[:]
a2[k] = re.sub(r'(α:\s+)(add\s+rsp)', r'\1push rbx; \2', a2[k])
r, got = run(write('run_l.s', a2), w1 + '/plan.txt')
grade('SPILL-PAIR: a lone push on the run to the exit (a call frame before the transfer) is an exit write, not a pair or an excursion',
      got.get('SPILL-PAIR', 0) == clean.get('SPILL-PAIR', 0) and got.get('EXCURSION', -1) == clean.get('EXCURSION', -2))

r, c1 = run(w1 + '/run.s', w1 + '/plan.txt')
rl = [l for l in r.stdout.splitlines() if l.startswith('RETAINING-EDGE ')]
tot = sum(c1.get(x, 0) for x in MISMATCH)
grade('RETAINING-EDGE: zl01 prints its retaining edges as lines (%d), equal to the count on the last line (%d)' % (len(rl), c1.get('RETAINING-EDGE', -1)), len(rl) > 0 and len(rl) == c1.get('RETAINING-EDGE', -1))
grade('RETAINING-EDGE: counted apart, not in mismatches (%d = the mismatch classes %d)' % (c1.get('mismatches', -1), tot), c1.get('mismatches', -1) == tot)
k = next((n for n, l in enumerate(asm) if re.match(r'^\s+\.quad\s+\.Lgcsite_\S+-\.Lgccode_\S+\s*$', l)), None)
w = int(asm[k + 1].split()[1])
a2 = asm[:]
a2[k + 1] = re.sub(r'\d+\s*$', str((w & ~(255 << 16)) | (5 << 16)), a2[k + 1])
r, got = run(write('run_5.s', a2), w1 + '/plan.txt')
rises('RULE5: a rule-0 site record made rule 5 reads RULE5', clean, got, 'RULE5')
a2 = asm[:]
a2[k + 1] = re.sub(r'\d+\s*$', str(w + (1 << 24)), a2[k + 1])
r, got = run(write('run_x1.s', a2), w1 + '/plan.txt')
grade('GC_SITE_EXT: a nonzero EXT byte in a record prints SITE-UNGRADED ext=nonzero count=1', 'SITE-UNGRADED ext=nonzero count=1' in r.stdout.splitlines(), 'no such line')

k6 = next((n for n, l in enumerate(asm) if re.match(r'^\s+\.quad\s+\.Lgcsite_\S+-\.Lgccode_\S+\s*$', l) and ((int(asm[n + 1].split()[1]) >> 16) & 255) == 6), None)
if k6 is None:
    print('GATE REFUSE(2) [%s]: no rule-6 GC site record in zl01 -- the witness drifted' % NAME)
    sys.exit(2)
w = int(asm[k6 + 1].split()[1])
a2 = asm[:]
a2[k6 + 1] = re.sub(r'\d+\s*$', str(w + (8 << 32)), a2[k6 + 1])
r, got = run(write('run_s6.s', a2), w1 + '/plan.txt')
rises('SITE: a rule-6 site record (its owning enter carries the depth) raised by 8 bytes reads SITE', clean, got, 'SITE')
grade('SITE rule 6: the clean zl01 grades its rule-6 records and reads no SITE-UNGRADED for rule 6', not any(l.startswith('SITE-UNGRADED rule=6') for l in subprocess.run([sys.executable, '-I', CHK, '--asm', w1 + '/run.s', '--plan', w1 + '/plan.txt'], capture_output=True, text=True).stdout.splitlines()))

w8 = TD + '/zl08_rk_lists_hashes'
r, c8 = run(w8 + '/run.s', w8 + '/plan.txt')
sm = [l for l in r.stdout.splitlines() if l.startswith('summary')]
by = {int(a): int(b) for a, b in re.findall(r'r(\d+):(\d+)', sm[0])} if sm else {}
ug = {int(a): int(b) for a, b in re.findall(r'^SITE-UNGRADED rule=(\d+) count=(\d+)$', r.stdout, re.M)}
hop = {int(a): int(b) for a, b in re.findall(r'^SITE-HOP rule=(\d+) count=(\d+)$', r.stdout, re.M)}
un = sorted(int(a) for a in re.findall(r'^SITE-UNEXERCISED rule=(\d+)$', r.stdout, re.M))
grade('SITE-UNGRADED: zl08 prints rule 2 (the plan dump carries no generator frame) with the summary\'s count (%s)' % by.get(2), bool(by.get(2)) and ug == {2: by[2]}, 'lines %s' % ug)
grade('SITE-HOP: zl08 prints rule 7 as a hop with the summary\'s count (%s)' % by.get(7), bool(by.get(7)) and hop == {7: by[7]}, 'lines %s' % hop)
grade('SITE-UNEXERCISED: zl08 prints every rule 0 to 9 it does not emit (%s)' % un, un == sorted(set(range(10)) - set(by)) and bool(un), 'emits %s' % sorted(by))

w7 = TD + '/zl07_pas_records_lists'
r, c7 = run(w7 + '/run.s', w7 + '/plan.txt')
a7 = open(w7 + '/run.s', encoding='utf-8').read().split('\n')
k = next((n for n, l in enumerate(a7) if re.match(r'^\s+\.quad\s+\.Lgcsite_\S+-\.Lgccode_\S+\s*$', l) and n + 1 < len(a7) and ((int(a7[n + 1].split()[1]) >> 16) & 255) == 1), None)
if k is None:
    print('GATE REFUSE(2) [%s]: no rule-1 GC site record in zl07 -- the witness drifted' % NAME)
    sys.exit(2)
w = int(a7[k + 1].split()[1])
a7[k + 1] = re.sub(r'\d+\s*$', str(w + (8 << 32)), a7[k + 1])
r, got = run(write('run_r1.s', a7), w7 + '/plan.txt')
rises('SITE: a rule-1 site record (the rbp home carries 0) raised by 8 bytes reads SITE', c7, got, 'SITE')

r, c2 = run(w2 + '/run.s', w2 + '/plan.txt')
tl = [l for l in r.stdout.splitlines() if l.startswith('TRANSFER-POP')]
grade('TRANSFER-POP: zl02 deferred gotos read as the leak they are (popped=0)', len(tl) >= 2 and all('popped=0' in l for l in tl), '%d lines' % len(tl))
if tl:
    m = re.match(r'TRANSFER-POP \S+ (n\d+_goto_deferred_bx) L\d+ popped=0 wanted=\d+', tl[0])
    if not m:
        grade('TRANSFER-POP: the first line names a goto_deferred box', False, tl[0])
    else:
        box = m.group(1)
        mine = [(int(x.group(1)), int(x.group(2))) for x in (re.match(r'TRANSFER-POP \S+ %s L(\d+) popped=0 wanted=(\d+)' % box, l) for l in tl) if x]
        a2 = open(w2 + '/run.s', encoding='utf-8').read().split('\n')
        cured = a2[:]
        for ln, owed in mine:
            cured[ln - 1] = re.sub(r'jmp\s+rax', 'add rsp, %d; jmp rax' % owed, cured[ln - 1])
        r, c3 = run(write('run_t.s', cured), w2 + '/plan.txt')
        left = sum(1 for l in r.stdout.splitlines() if l.startswith('TRANSFER-POP') and (' %s ' % box) in l)
        grade('TRANSFER-POP: the owed pop added before the flagged jmp rax of %s reads fewer (%d -> %d)' % (box, len(mine), left), len(mine) >= 1 and left == 0)
        wrong = a2[:]
        for ln, owed in mine:
            wrong[ln - 1] = re.sub(r'jmp\s+rax', 'add rsp, %d; jmp rax' % (owed + 8), wrong[ln - 1])
        r, c4 = run(write('run_w.s', wrong), w2 + '/plan.txt')
        left = sum(1 for l in r.stdout.splitlines() if l.startswith('TRANSFER-POP') and (' %s ' % box) in l and re.search(r'popped=(\d+) wanted=(\d+)', l) and int(re.search(r'popped=(\d+) wanted=(\d+)', l).group(1)) == int(re.search(r'popped=(\d+) wanted=(\d+)', l).group(2)) + 8)
        grade('TRANSFER-POP: a WRONG pop (8 more than owed) still reads, with the amount it popped', left == len(mine), '%d of %d' % (left, len(mine)))

zs = TD + '/zsm'
r, got = run(zs + '/run.s', zs + '/plan.txt')
summ = [l for l in r.stdout.splitlines() if l.startswith('summary')]
nz = int(re.search(r'zsm=(\d+)\)', summ[0]).group(1)) if summ else 0
grade('ZSM: the instrument\'s balanced push/pop around rt_zdp_ev is counted as skipped (zsm=%d)' % nz, nz > 0)
grade('ZSM: it adds no EXCURSION over the clean reading (%d vs %d)' % (got.get('EXCURSION', -1), clean.get('EXCURSION', -2)), got.get('EXCURSION', -1) == clean.get('EXCURSION', -2))

gi = max(n for n, l in enumerate(plan) if l.startswith('PLAN graph='))
r, got = run(w1 + '/run.s', write('plan_a.txt', plan[:gi]))
grade('ALIGN: a plan with its last graph cut off reads ALIGN', got.get('ALIGN', 0) >= 1, 'ALIGN=%s' % got.get('ALIGN'))

r = subprocess.run([sys.executable, '-I', CHK, '--asm', TD + '/no_such.s', '--plan', w1 + '/plan.txt'], capture_output=True, text=True)
grade('rc 2 and no mismatches= line on an unreadable input', r.returncode == 2 and 'mismatches=' not in r.stdout, 'rc=%d' % r.returncode)
print('%s: graded=%d fails=%d' % (NAME, graded, fails))
if fails:
    print('⛔ GATE RED [%s]: %d of %d arm(s) failed' % (NAME, fails, graded))
    sys.exit(1)
print('GATE PASS(0) [%s]: %d arm(s) -- the layout checker reads more on every corrupted input, fewer on the cure, and nothing for the ZSM instrument' % (NAME, graded))
PY
