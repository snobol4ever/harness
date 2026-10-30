#!/usr/bin/env bash
# test_gate_zeta_layout_check_negative_controls_red.sh -- THE LAYOUT CHECKER CAN FAIL (DESIGN-PLAN zeta-layout step 1; ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH 5; CEO-2019).
# harness/scripts/util_zeta_layout_check.py reads a program's mode-4 text against ./scrip --dump-plan. A checker that reads 0 proves nothing until it is shown to read
# more on a corrupted input, so each arm CORRUPTS A COPY OF THE CHECKER'S OWN INPUT (never a line of SCRIP's src, CEO-1680: a witness shown red against a corrupted
# reference) and demands that exactly the class the corruption belongs to rises over the clean reading:
#   CARVE         the plan's K for one lit_integer row made 48 (the box still carves 16)
#   EXCURSION     a push and a pop split by a conditional jump, planted in a lit_integer box
#   EDGE          the pop removed from a statement_end box's exit jump, so it lands deeper than the next box's entry
#   SITE          a rule-0 GC site record's depth word raised by 8
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
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
for w in zl01_sno_captures_eval zl02_sno_setexit_code; do
    mkdir -p "$TD/$w"
    ( cd "$TD/$w" && timeout -k 5 120 "$SCRIP" --compile --out="$TD/$w/run.s" "$WD/$w.sno" < /dev/null > /dev/null 2> compile.err ) || refuse "$w did not compile in mode 4: $(head -c 200 "$TD/$w/compile.err")"
    ( cd "$TD/$w" && timeout -k 5 120 "$SCRIP" --dump-plan "$WD/$w.sno" < /dev/null > "$TD/$w/plan.txt" 2> plan.err ) || refuse "$w --dump-plan failed: $(head -c 200 "$TD/$w/plan.err")"
done
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
    c = {k: int(v) for k, v in re.findall(r'([A-Za-z-]+)=(\d+)', last)}
    return r, c


def grade(label, ok, detail=''):
    global graded, fails
    graded += 1
    if ok:
        print('  ok   ' + label)
    else:
        fails += 1
        print('  ⛔ FAIL ' + label + (': ' + detail if detail else ''))


def rises(label, clean, got, cls):
    others = [k for k in ('EXCURSION', 'CARVE', 'EDGE', 'TRANSFER-POP', 'SITE', 'ALIGN') if k != cls and got.get(k, 0) < clean.get(k, 0)]
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

r, c2 = run(w2 + '/run.s', w2 + '/plan.txt')
tl = [l for l in r.stdout.splitlines() if l.startswith('TRANSFER-POP')]
grade('TRANSFER-POP: zl02 deferred gotos read as the leak they are (popped=0)', len(tl) >= 2 and all('popped=0' in l for l in tl), '%d lines' % len(tl))
if tl:
    m = re.match(r'TRANSFER-POP \S+ (n\d+_goto_deferred_bx) L\d+ popped=0 wanted=(\d+)', tl[0])
    if not m:
        grade('TRANSFER-POP: the first line names a goto_deferred box', False, tl[0])
    else:
        box, owed = m.group(1), int(m.group(2))
        a2 = open(w2 + '/run.s', encoding='utf-8').read().split('\n')
        lo = next(n for n, l in enumerate(a2) if re.match(r'^\s+\.type\s+%s,' % box, l))
        hi = next(n for n in range(lo, len(a2)) if re.match(r'^\s+\.size\s+%s,' % box, a2[n]))
        cured = a2[:]
        for n in range(lo, hi):
            cured[n] = re.sub(r'jmp\s+rax', 'add rsp, %d; jmp rax' % owed, cured[n])
        before = sum(1 for l in tl if (' %s ' % box) in l)
        r, c3 = run(write('run_t.s', cured), w2 + '/plan.txt')
        left = sum(1 for l in r.stdout.splitlines() if l.startswith('TRANSFER-POP') and (' %s ' % box) in l)
        grade('TRANSFER-POP: the owed pop (%d) added before each jmp rax of %s reads fewer (%d -> %d)' % (owed, box, before, left), before >= 1 and left == 0)
        wrong = a2[:]
        for n in range(lo, hi):
            wrong[n] = re.sub(r'jmp\s+rax', 'add rsp, %d; jmp rax' % (owed + 8), wrong[n])
        r, c4 = run(write('run_w.s', wrong), w2 + '/plan.txt')
        left = sum(1 for l in r.stdout.splitlines() if l.startswith('TRANSFER-POP') and (' %s ' % box) in l and ('popped=%d ' % (owed + 8)) in l)
        grade('TRANSFER-POP: a WRONG pop (%d, owed %d) still reads, with the amount it popped' % (owed + 8, owed), left == before, '%d of %d' % (left, before))

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
