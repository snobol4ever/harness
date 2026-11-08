#!/usr/bin/env bash
# test_score_row_refuses_pass_above_total.sh -- the score writer's fraction reader refuses a pass above its total (officer_05 and senior_08, 2026-11-08).
# rc 0 GREEN: fraction_from_text("3","2") returns no reading naming "is above its total" and ("2","3") still reads. rc 1 RED. rc 2 REFUSE: the writer cannot be loaded.
S4E_ROOT="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
f="$S4E_ROOT/harness/scripts/util_score_row.py"
[ -f "$f" ] || { echo "REFUSE(2): $f missing"; exit 2; }
timeout -k 5 60 python3 -I - "$f" < /dev/null <<'PY' || exit $?
import importlib.util, sys
try:
    s = importlib.util.spec_from_file_location("usr", sys.argv[1])
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    a = m.fraction_from_text(None, "3", "2")
    b = m.fraction_from_text(None, "2", "3")
except Exception as e:
    print("REFUSE(2): the writer did not load: %r" % (e,))
    sys.exit(2)
ok = a[0] is None and a[1] is None and "is above its total" in (a[2] or "") and b == ("2", "3", None)
print("pass above total: %r; pass below total: %r" % (a, b))
print("GATE OK [test_score_row_refuses_pass_above_total]" if ok else "GATE FAIL [test_score_row_refuses_pass_above_total]")
sys.exit(0 if ok else 1)
PY
