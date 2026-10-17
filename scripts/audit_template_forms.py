#!/usr/bin/env python3
"""audit_template_forms.py -- THE FORM CENSUS: every box that serves more than one IR form, and the split each needs.

Lon 2026-09-27, in-chat to the ceo, verbatim: "This template code health reaches beyond fixing any BB for the many
IR's it handles, but to consider having other IR/BB broken out properly by form/pattern." (hq_templates, row
templates-a-form-census-names-every-box-that-serves-more-than-one-ir-form-and-the-split-each-needs, CEO-1321.)

A file at audit rc 0 is not yet healthy if ONE box emits MANY patterns. The health target is ONE FORM PER BOX
(GOAL-BB-FIXUP.md ONE-IR-ONE-LOGIC, TIER S): lower chooses the form, each template emits one pattern straight through.
This census measures the two places a form can be chosen OTHER than lower, and prints the break-out each needs:

  1. THE TEMPLATE CHOOSES. A box's entry function (std::string bb_X()) holds several EMISSION PATHS. A path is one
     return, split further by a switch case, by a top-level ternary of the returned expression, or -- when a return
     is a sum of top-level IF(cond, ...) terms of which two or more open the box's own alpha (x86_alpha()) -- by
     each such IF. A path whose whole emission is an alpha plus bombs is counted as a REFUSAL (an unsupported shape
     declared, not a form). LIVE FORMS = paths that are not refusals. A box with LIVE FORMS > 1 needs one box per form,
     the form chosen in lower (a distinct IR kind) -- the guards printed are the conditions lower must decide.
  2. THE EMITTER CHOOSES. A case group of walk_bb_node_inner's switch (src/emitter/emit.cpp) that hands one IR kind
     to two or more boxes by a condition decides the form in C, after lower: each box it can reach wants its own IR
     kind, so the case becomes one kind -> one box.
  3. and, informational, BOXES SERVING SEVERAL KINDS: healthy when the box has one form; when it has several, its
     forms are often the kinds it serves, told apart again inside the template.

THE UNIT is the box entry a dispatch site names (bb_emit_x86(bb_X()) anywhere in emit.cpp), found in the template
file that defines std::string bb_X(); every bb_*.cpp and xa_*.cpp file is listed in the population, and a file
whose entry no site names is counted as undispatched (a helper or an xa emission piece).

Usage: python3 ../harness/scripts/audit_template_forms.py [--root DIR] [--tsv] [--top N]
  rc 0  no box carries more than one live form and no kind case picks among boxes
  rc 1  some box or kind case does (the census's debt, like the rank audit's rc 1 while a file is dirty)
  rc 2  the emitter's switch or the population cannot be read (never a pass)
--tsv prints one row per box (box, file, kinds, sites, forms, live, refusals), then one row per IR kind of the switch
(kind, IR_X, its boxes joined by |), for the watch loop to diff two readings.
"""
import argparse, glob, os, re, subprocess, sys

ALPHA = "x86_alpha()"
NOT = "\u00ac "


def strip(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append(c + "".join("_" if ch in "(){}[];?:,+\\\"'" else ch for ch in src[i + 1:j]) + c)
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def close_of(t, i):
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = []
    for j in range(i, len(t)):
        if t[j] in pairs:
            stack.append(pairs[t[j]])
        elif t[j] in ")]}":
            if not stack or stack.pop() != t[j]:
                return -1
            if not stack:
                return j
    return -1


def to_semicolon(t, i):
    depth = 0
    for j in range(i, len(t)):
        if t[j] in "([{":
            depth += 1
        elif t[j] in ")]}":
            depth -= 1
        elif t[j] == ";" and depth == 0:
            return j
    return len(t)


def word_at(t, i, w):
    return t.startswith(w, i) and (i + len(w) >= len(t) or not (t[i + len(w)].isalnum() or t[i + len(w)] == "_")) \
        and (i == 0 or not (t[i - 1].isalnum() or t[i - 1] == "_"))


def skip_ws(t, i):
    while i < len(t) and t[i].isspace():
        i += 1
    return i


def one_statement(t, i):
    i = skip_ws(t, i)
    if i >= len(t):
        return i, i
    if t[i] == "{":
        e = close_of(t, i)
        return i, (len(t) - 1 if e < 0 else e) + 1
    for kw in ("if", "for", "while", "switch"):
        if word_at(t, i, kw):
            p = t.find("(", i)
            q = close_of(t, p)
            s, e = one_statement(t, q + 1)
            if kw == "if":
                k = skip_ws(t, e)
                if word_at(t, k, "else"):
                    s2, e = one_statement(t, k + 4)
            return i, e
    return i, to_semicolon(t, i) + 1


def statements(t):
    i = 0
    while True:
        i = skip_ws(t, i)
        if i >= len(t):
            return
        if word_at(t, i, "case") or word_at(t, i, "default"):
            j = i
            while j < len(t):
                if t[j] == ":" and not t.startswith("::", j) and (j == 0 or t[j - 1] != ":"):
                    break
                j += 1
            yield ("label", t[i:j].strip())
            i = j + 1
            continue
        if word_at(t, i, "if"):
            p = t.find("(", i)
            q = close_of(t, p)
            s, e_then = one_statement(t, q + 1)
            e, els = e_then, None
            k = skip_ws(t, e_then)
            if word_at(t, k, "else"):
                s2, e = one_statement(t, k + 4)
                els = t[s2:e]
            yield ("if", t[p + 1:q].strip(), t[s:e_then], els)
            i = e
            continue
        if word_at(t, i, "switch"):
            p = t.find("(", i)
            q = close_of(t, p)
            b = t.find("{", q)
            e = close_of(t, b)
            yield ("switch", t[p + 1:q].strip(), t[b + 1:e])
            i = e + 1
            continue
        if word_at(t, i, "return"):
            e = to_semicolon(t, i)
            yield ("return", t[i + 6:e].strip())
            i = e + 1
            continue
        if t[i] == "{":
            e = close_of(t, i)
            yield ("block", t[i + 1:e])
            i = e + 1
            continue
        s, e = one_statement(t, i)
        yield ("stmt", t[s:e])
        i = max(e, i + 1)


def unblock(t):
    t = t.strip()
    if t.startswith("{") and close_of(t, 0) == len(t) - 1:
        return t[1:-1]
    return t


def top_level_ternary(e):
    depth, j = 0, 0
    while j < len(e):
        c = e[j]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "?" and depth == 0:
            nest, k = 0, j + 1
            while k < len(e):
                d = e[k]
                if d in "([{":
                    depth += 1
                elif d in ")]}":
                    depth -= 1
                elif depth == 0 and d == "?":
                    nest += 1
                elif depth == 0 and d == ":" and not e.startswith("::", k) and e[k - 1] != ":":
                    if nest == 0:
                        return e[:j].strip(), e[j + 1:k].strip(), e[k + 1:].strip()
                    nest -= 1
                k += 1
            return None
        j += 1
    return None


def top_level_if_terms(e):
    terms, depth, j, start = [], 0, 0, 0
    while j < len(e):
        c = e[j]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "+" and depth == 0:
            terms.append(e[start:j].strip())
            start = j + 1
        j += 1
    terms.append(e[start:].strip())
    out = []
    for term in terms:
        m = re.match(r"IF\s*\(", term)
        if m and close_of(term, m.end() - 1) == len(term) - 1:
            inner = term[m.end():-1]
            depth, k = 0, 0
            while k < len(inner):
                if inner[k] in "([{":
                    depth += 1
                elif inner[k] in ")]}":
                    depth -= 1
                elif inner[k] == "," and depth == 0:
                    break
                k += 1
            out.append((inner[:k].strip(), inner[k + 1:].strip()))
        else:
            out.append((None, term))
    return out


def lambda_body(e):
    m = re.match(r"\[[&=]?[^\]]*\]\s*\(", e)
    if not m:
        return None
    q = close_of(e, m.end() - 1)
    b = skip_ws(e, q + 1)
    if b >= len(e) or e[b] != "{":
        return None
    z = close_of(e, b)
    return e[b + 1:z]


def split_return(e, guards):
    lb = lambda_body(e)
    if lb is not None:
        return paths(lb, guards)
    t = top_level_ternary(e)
    if t:
        c, a, rest = t
        return split_return(a, guards + [c]) + split_return(rest, guards + [NOT + c])
    terms = top_level_if_terms(e)
    alpha_ifs = [(c, b) for c, b in terms if c is not None and ALPHA in b]
    if len(alpha_ifs) >= 2:
        return [(guards + [c], b) for c, b in alpha_ifs]
    return [(guards, e)]


def paths(body, guards):
    out, label = [], None
    for st in statements(body):
        if st[0] == "return":
            out += split_return(st[1], guards + ([label] if label else []))
        elif st[0] == "if":
            out += paths(unblock(st[2]), guards + [st[1]])
            if st[3] is not None:
                out += paths(unblock(st[3]), guards + [NOT + st[1]])
        elif st[0] == "block":
            out += paths(st[1], guards)
        elif st[0] == "switch":
            lab = None
            for sub in statements(st[2]):
                if sub[0] == "label":
                    lab = st[1] + " " + sub[1]
                elif sub[0] == "return":
                    out += split_return(sub[1], guards + [lab or st[1]])
                elif sub[0] in ("block", "if"):
                    inner = sub[1] if sub[0] == "block" else unblock(sub[2])
                    out += paths(inner, guards + ([lab] if lab else []) + ([sub[1]] if sub[0] == "if" else []))
    return out


def is_refusal(expr):
    rest = re.sub(r"x86_(alpha|beta|gamma|omega)\(\)|x86_bomb\(\"[^\"]*\"(\s*\"[^\"]*\")*\)|\+|\s|\(|\)", "", expr)
    return "x86_bomb(" in expr and rest == ""


def kind_for(kind, box):
    stem, base = box[3:], kind[3:].lower()
    rest = stem[len(base):].lstrip("_") if stem.startswith(base) else stem
    return kind + ("_" + rest.upper() if rest else "")


def functions(text):
    for m in re.finditer(r"^(?:static\s+)?(?:inline\s+)?std::string\s+(\w+)\s*\(([^)]*)\)\s*\{", text, re.M):
        b = m.end() - 1
        e = close_of(text, b)
        yield m.group(1), text[b + 1:e]


def dispatch(root):
    p = os.path.join(root, "src/emitter/emit.cpp")
    if not os.path.isfile(p):
        return None, None, None
    t = strip(open(p, encoding="utf-8", errors="replace").read())
    sites = {}
    for m in re.finditer(r"bb_emit_x86\s*\(", t):
        e = close_of(t, m.end() - 1)
        for b in re.findall(r"\b(bb_\w+)\s*\(\s*\)", t[m.end():e]):
            sites[b] = sites.get(b, 0) + 1
    m = re.search(r"static\s+int\s+walk_bb_node_inner\s*\([^)]*\)\s*\{", t)
    if not m:
        return sites, None, None
    body = t[m.end():close_of(t, m.end() - 1)]
    sw = re.search(r"switch\s*\(\s*nd->op\s*\)\s*\{", body)
    if not sw:
        return sites, None, None
    inner = body[sw.end():close_of(body, sw.end() - 1)]
    groups, cur = [], []
    level, depth_at = 0, []
    for ch in inner:
        depth_at.append(level)
        level += 1 if ch == "{" else -1 if ch == "}" else 0
    marks = [(mm.start(), mm.group(1)) for mm in re.finditer(r"\bcase\s+(IR_\w+)\s*:", inner) if depth_at[mm.start()] == 0]
    for idx, (pos, kind) in enumerate(marks):
        seg_end = marks[idx + 1][0] if idx + 1 < len(marks) else len(inner)
        seg = inner[pos:seg_end]
        seg_body = re.sub(r"^\s*case\s+IR_\w+\s*:", "", seg)
        cur.append(kind)
        if seg_body.strip():
            groups.append((cur, seg_body))
            cur = []
    kinds_of, box_of_kind = {}, {}
    for ks, sb in groups:
        boxes = []
        for mm in re.finditer(r"bb_emit_x86\s*\(", sb):
            e = close_of(sb, mm.end() - 1)
            for b in re.findall(r"\b(bb_\w+)\s*\(\s*\)", sb[mm.end():e if e > 0 else len(sb)]):
                if b not in boxes:
                    boxes.append(b)
        for k in ks:
            box_of_kind[k] = boxes
            for b in boxes:
                kinds_of.setdefault(b, []).append(k)
    return sites, kinds_of, box_of_kind


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"))
    ap.add_argument("--tsv", action="store_true")
    ap.add_argument("--top", type=int, default=0)
    a = ap.parse_args()
    root = a.root
    files = sorted(glob.glob(os.path.join(root, "src/templates/bb/bb_*.cpp"))) + \
        sorted(glob.glob(os.path.join(root, "src/templates/xa/xa_*.cpp")))
    sites, kinds_of, box_of_kind = dispatch(root)
    if sites is None or kinds_of is None:
        print("GATE UNPROVEN(2) [audit_template_forms]: cannot read walk_bb_node_inner's switch (nd->op) in %s/src/emitter/emit.cpp" % root)
        return 2
    if len(files) < 50:
        print("GATE UNPROVEN(2) [audit_template_forms]: examined %d bb_*/xa_* template files, floor is 50" % len(files))
        return 2
    defined = {}
    for f in files:
        t = strip(open(f, encoding="utf-8", errors="replace").read())
        for name, body in functions(t):
            if name.startswith("bb_") and name not in defined:
                defined[name] = (f, body)
    rows = []
    for box in sorted(set(sites) | set(kinds_of)):
        if box not in defined:
            continue
        f, body = defined[box]
        ps = paths(body, [])
        if not ps:
            ps = [([], body)]
        refusal = [p for p in ps if is_refusal(p[1])]
        live = [p for p in ps if not is_refusal(p[1])]
        rows.append({"box": box, "file": os.path.relpath(f, root), "kinds": kinds_of.get(box, []),
                     "sites": sites.get(box, 0), "forms": len(ps), "live": len(live), "refusal": len(refusal), "paths": ps})
    dispatched_files = {r["file"] for r in rows}
    undispatched = [os.path.relpath(f, root) for f in files if os.path.relpath(f, root) not in dispatched_files]
    multi_form = sorted([r for r in rows if r["live"] > 1], key=lambda r: (-r["live"], -len(r["kinds"]), r["box"]))
    multi_box = sorted([(k, bs) for k, bs in box_of_kind.items() if len(bs) > 1], key=lambda kb: (-len(kb[1]), kb[0]))
    multi_kind = sorted([r for r in rows if len(r["kinds"]) > 1], key=lambda r: (-len(r["kinds"]), r["box"]))
    if a.tsv:
        print("box\tfile\tkinds\tsites\tforms\tlive\trefusals")
        for r in rows:
            print("%s\t%s\t%s\t%d\t%d\t%d\t%d" % (r["box"], r["file"], ",".join(r["kinds"]) or "-", r["sites"], r["forms"], r["live"], r["refusal"]))
        for k, bs in sorted(box_of_kind.items()):
            print("kind\t%s\t%s" % (k, "|".join(bs) or "-"))
        return 1 if (multi_form or multi_box) else 0
    try:
        sha = subprocess.run(["git", "-C", root, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() or "unknown"
    except OSError:
        sha = "unknown"
    print("=== TEMPLATE FORM CENSUS (%s @ %s) ===" % (root, sha))
    print("  population: %d template files (%d bb + %d xa); %d boxes named by a dispatch site; %d files with no dispatched box"
          % (len(files), sum(1 for f in files if "/bb/" in f), sum(1 for f in files if "/xa/" in f), len(rows), len(undispatched)))
    print("  kinds: %d IR kinds in walk_bb_node_inner's switch; %d boxes carry more than one live form; %d kinds pick among boxes in the emitter"
          % (len(box_of_kind), len(multi_form), len(multi_box)))
    print("--- 1. THE TEMPLATE CHOOSES: boxes with more than one live form (split: one box per form, the form chosen in lower) ---")
    shown = multi_form[:a.top] if a.top else multi_form
    for r in shown:
        print("  live=%d forms=%d refusals=%d  %s  (%s)  kinds: %s  sites: %d"
              % (r["live"], r["forms"], r["refusal"], r["box"], r["file"], " ".join(r["kinds"]) or "none in the kind switch", r["sites"]))
        n = 0
        for g, e in r["paths"]:
            if is_refusal(e):
                continue
            n += 1
            own = [re.sub(r"\s+", " ", x) for x in g if not x.startswith(NOT)]
            guard = " && ".join(own) if own else "(otherwise)"
            print("      form %d: %s" % (n, guard[:300]))
        print("      BREAK-OUT: %d one-form boxes %s; lower decides the %d guards above, one IR kind per form%s"
              % (r["live"], ", ".join("%s_f%d" % (r["box"], i + 1) for i in range(r["live"])), r["live"],
                 (" (the kind%s it serves today: %s)" % ("s" if len(r["kinds"]) > 1 else "", " ".join(r["kinds"]))) if r["kinds"] else ""))
    if a.top and len(multi_form) > a.top:
        print("  ... %d more (--top 0 prints all)" % (len(multi_form) - a.top))
    print("--- 2. THE EMITTER CHOOSES: kind cases that pick among boxes (add one IR kind per box in lower) ---")
    for k, bs in multi_box:
        print("  %s -> %s   BREAK-OUT: %s" % (k, " | ".join(bs), ", ".join(kind_for(k, b) for b in bs)))
    print("--- 3. BOXES SERVING SEVERAL KINDS (healthy at one form) ---")
    for r in multi_kind:
        print("  kinds=%d live=%d  %s: %s" % (len(r["kinds"]), r["live"], r["box"], " ".join(r["kinds"])))
    debt = len(multi_form) + len(multi_box)
    print("  VERDICT: %d box(es) with more than one live form, %d kind case(s) choosing among boxes" % (len(multi_form), len(multi_box)))
    if debt:
        print("GATE FAIL(1) [audit_template_forms]: %d form choice(s) made outside lower (examined %d boxes)" % (debt, len(rows)))
        return 1
    print("GATE PASS(0) [audit_template_forms]: every box one form, every kind one box (examined %d boxes)" % len(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
