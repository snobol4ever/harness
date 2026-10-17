#!/usr/bin/env python3
"""gen_callee_arg_roles.py -- OBJ-NOTE ON-3: derive the callee argument-ROLE table from the REAL runtime
prototypes, never from invented names.  For every callee named by an x86("call", ...) site in the templates,
find its C prototype, then walk its parameters assigning SysV AMD64 integer-register slots:
  DESCR_t (16B, both eightbytes INTEGER -- verified empirically) => TWO slots, BOTH naming the same object
  float/double                                                   => ZERO integer slots (rides SSE)
  struct returned by value and larger than 16B                   => a hidden sret pointer occupies slot 0
  everything else (scalar / pointer / enum)                      => ONE slot
Anything this cannot classify with certainty is DROPPED, not guessed: a wrong role term is worse than none,
because the whole point of the annotation is that Lon can trust it while directing deletions."""
import os, re, subprocess, sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
SRC = os.path.normpath(SRC)
ARGREGS = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]
KNOWN16 = {"DESCR_t"}
SCALARS = {"int", "long", "char", "short", "unsigned", "size_t", "int8_t", "int16_t", "int32_t", "int64_t",
           "uint8_t", "uint16_t", "uint32_t", "uint64_t", "void", "_Bool", "bool", "intptr_t", "uintptr_t",
           "DTYPE_t", "ptrdiff_t", "ssize_t", "off_t", "FILE"}
FLOATS = {"float", "double"}


def collect_callees():
    out = set()
    tdir = os.path.join(SRC, "templates")
    pat = re.compile(r'x86\(\s*"call"\s*,\s*"([A-Za-z_0-9]+)"')
    for d, _, fns in os.walk(tdir):
        for fn in fns:
            if not fn.endswith(".cpp"):
                continue
            with open(os.path.join(d, fn), "r", errors="replace") as f:
                for m in pat.finditer(f.read()):
                    out.add(m.group(1))
    return sorted(out)


CKEYWORDS = {"return", "else", "case", "goto", "do", "sizeof", "typedef", "defined", "if", "for", "while",
             "switch", "break", "continue", "and", "or", "not", "new", "delete", "throw"}


def looks_declarative(params):
    """A real prototype's parameters carry TYPES.  `return foo(a, b);` looks identical to a declaration to a
    line regex, and mis-parsing it invents role names out of local variables -- the exact failure this
    generator exists to avoid.  Demand every parameter be a type+name pair, a bare type, or void/varargs."""
    ps = split_params(params)
    if not ps or (len(ps) == 1 and ps[0].strip() in ("void", "")):
        return True
    for p in ps:
        p = p.strip()
        if p == "...":
            continue
        if "*" in p or "[" in p:
            continue
        if len(base_type(p)) < 2:
            return False
    return True


def scan_prototypes():
    """Collect EVERY `rettype name(params)` declaration, then accept a name only when the surviving
    candidates AGREE on the parameter list.  Header declarations win over in-file definitions."""
    cand = {}
    decl = re.compile(r'(?m)^[ \t]*((?:extern[ \t]+|static[ \t]+|inline[ \t]+)*'
                      r'(?:const[ \t]+|unsigned[ \t]+|signed[ \t]+|struct[ \t]+)*'
                      r'[A-Za-z_][A-Za-z_0-9]*[ \t\*]+)([A-Za-z_][A-Za-z_0-9]*)[ \t]*\(([^;{)]*)\)[ \t\r\n]*[;{]')
    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in ("attic", "backends")]
        for fn in sorted(files):
            if not fn.endswith((".c", ".h", ".cpp")):
                continue
            p = os.path.join(root, fn)
            try:
                txt = open(p, "r", errors="replace").read()
            except OSError:
                continue
            for m in decl.finditer(txt):
                ret, name, params = m.group(1).strip(), m.group(2), m.group(3).strip()
                if name in CKEYWORDS:
                    continue
                head = [w for w in ret.replace("*", " ").split() if w]
                if head and head[0] in CKEYWORDS:
                    continue                                  # `return foo(a,b);` is NOT a declaration
                if not looks_declarative(params):
                    continue
                cand.setdefault(name, []).append((fn.endswith(".h"), ret, params))
    protos, conflicts = {}, {}
    for name, lst in cand.items():
        hdr = [c for c in lst if c[0]]
        use = hdr if hdr else lst
        sigs = {}
        for _h, ret, params in use:
            key = tuple(param_name(p) or "" for p in split_params(params))
            sigs.setdefault(key, (ret, params))
        if len(sigs) > 1:
            conflicts[name] = sorted("(%s)" % ", ".join(k) for k in sigs)
            continue
        protos[name] = list(sigs.values())[0]
    return protos, conflicts


REG32 = {"edi": 0, "esi": 1, "edx": 2, "ecx": 3, "r8d": 4, "r9d": 5,
         "rdi": 0, "rsi": 1, "rdx": 2, "rcx": 3, "r8": 4, "r9": 5,
         "dil": 0, "sil": 1, "dl": 2, "cl": 3}


def scan_asm_contracts():
    """The RTX asm ports declare a LEAN CUSTOM CONVENTION that is explicitly NOT the C ABI, so a
    C-prototype-derived role would be WRONG for them.  They do document the real contract in their header
    banner (`rt_sg_member: in edi=char, rsi=needle ptr, edx=needle len; out eax=...`) -- parse THAT."""
    out, rt = {}, os.path.join(SRC, "runtime")
    line_re = re.compile(r'([A-Za-z_][A-Za-z_0-9]*)\s*:\s*(same contract|in\s+.*?)(?:;|\*/|$)')
    pair_re = re.compile(r'\b(' + "|".join(sorted(REG32, key=len, reverse=True)) + r')\s*=\s*([A-Za-z_][A-Za-z_0-9 ]*)')
    for root, _d, files in os.walk(rt):
        for fn in sorted(files):
            if not fn.endswith((".S", ".s")):
                continue
            prev = None
            for raw in open(os.path.join(root, fn), "r", errors="replace"):
                if "/*" not in raw and "*" not in raw:
                    continue
                m = line_re.search(raw)
                if not m:
                    continue
                name, body = m.group(1), m.group(2)
                if body.startswith("same contract"):
                    if prev and prev in out:
                        out[name] = list(out[prev])
                        prev = name
                    continue
                roles = [None] * 6
                found = False
                for reg, role in pair_re.findall(body):
                    term = "_".join(role.split()[:2]).strip("_").lower()
                    if term:
                        roles[REG32[reg]] = term
                        found = True
                if found:
                    while roles and roles[-1] is None:
                        roles.pop()
                    out[name] = roles
                    prev = name
    return out


def struct_sizes(names):
    """Ask the COMPILER for sizes -- never guess a struct's class."""
    if not names:
        return {}
    inc = ["-I", os.path.join(SRC, "contracts"), "-I", os.path.join(SRC, "include"),
           "-I", os.path.join(SRC, "runtime"), "-I", os.path.join(SRC, "runtime", "core"),
           "-I", SRC, "-I", os.path.join(SRC, "emitter")]
    body = ['#include <stdio.h>', '#include "descr.h"']
    for h in ("core.h", "rt.h", "runtime.h"):
        for root, _d, files in os.walk(SRC):
            if h in files:
                body.append('#include "%s"' % os.path.join(root, h))
                break
    body.append("int main(void){")
    ok = []
    for n in sorted(names):
        ok.append(n)
        body.append('  printf("%%s %%zu\\n", "{0}", sizeof({0}));'.format(n))
    body.append("  return 0; }")
    src = "/tmp/on3/_sz.c"
    open(src, "w").write("\n".join(body) + "\n")
    exe = "/tmp/on3/_sz"
    r = subprocess.run(["gcc", "-w"] + inc + [src, "-o", exe], capture_output=True, text=True)
    if r.returncode != 0:
        return {}
    r = subprocess.run([exe], capture_output=True, text=True)
    res = {}
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2:
            res[parts[0]] = int(parts[1])
    return res


def base_type(tok):
    t = tok.replace("const", " ").replace("volatile", " ").replace("struct", " ")
    t = t.replace("*", " ").replace("[", " ").replace("]", " ")
    return [w for w in t.split() if w]


def split_params(params):
    out, depth, cur = [], 0, ""
    for ch in params:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [p.strip() for p in out if p.strip()]


def param_name(p):
    if "(" in p and "*" in p:                      # function pointer -- name is inside the parens
        m = re.search(r'\(\s*\*\s*([A-Za-z_][A-Za-z_0-9]*)\s*\)', p)
        return m.group(1) if m else None
    m = re.search(r'([A-Za-z_][A-Za-z_0-9]*)\s*(?:\[\s*\d*\s*\])?\s*$', p)
    if not m:
        return None
    nm = m.group(1)
    if nm in SCALARS or nm in FLOATS or nm in KNOWN16:
        return None                                 # unnamed parameter (type only) -- no role to report
    return nm


def slots_for(p, sizes):
    """How many INTEGER argument registers this parameter consumes."""
    if "*" in p or "[" in p:
        return 1
    words = base_type(p)
    if not words:
        return None
    if any(w in FLOATS for w in words):
        return 0
    for w in words:
        if w in KNOWN16:
            return 2
        if w in sizes:
            sz = sizes[w]
            if sz <= 8:
                return 1
            if sz <= 16:
                return 2
            return 0                                # >16B by value rides MEMORY, no register
    if any(w in SCALARS for w in words):
        return 1
    return None                                     # unknown type -- refuse to guess


def ret_uses_sret(ret, sizes):
    if "*" in ret:
        return False
    words = base_type(ret)
    for w in words:
        if w in KNOWN16:
            return False                            # 16B rides rax:rdx, no hidden pointer
        if w in sizes:
            return sizes[w] > 16
    return False


def main():
    callees = collect_callees()
    protos, conflicts = scan_prototypes()
    asmc = scan_asm_contracts()
    typenames = set()
    for name in callees:
        if name not in protos:
            continue
        ret, params = protos[name]
        for tok in [ret] + split_params(params):
            for w in base_type(tok):
                if w not in SCALARS and w not in FLOATS and w[0].isupper() or w in KNOWN16:
                    typenames.add(w)
    sizes = struct_sizes(typenames)
    LIBC = {"memcmp": ["s1", "s2", "n"], "strchr": ["s", "c"], "strlen": ["s"], "putchar": ["c"], "memcpy": ["dst", "src", "n"], "strcmp": ["s1", "s2"]}
    rows, skipped = [], []
    for name in callees:
        if name in LIBC:
            rows.append((name, LIBC[name]))
            continue
        if name in asmc:
            rows.append((name, asmc[name]))
            continue
        if name in conflicts:
            skipped.append((name, "CONFLICTING declarations: " + " vs ".join(conflicts[name])))
            continue
        if name not in protos:
            skipped.append((name, "no prototype found"))
            continue
        ret, params = protos[name]
        plist = split_params(params)
        if len(plist) == 1 and plist[0].strip() in ("void", ""):
            plist = []
        roles = [None] * 6
        idx = 0
        if ret_uses_sret(ret, sizes):
            roles[0] = "sret"
            idx = 1
        bad = None
        for p in plist:
            if p.strip() == "...":
                break
            n = slots_for(p, sizes)
            if n is None:
                bad = "unclassifiable param: %s" % p.strip()
                break
            nm = param_name(p)
            for _ in range(n):
                if idx < 6 and nm:
                    roles[idx] = nm
                idx += 1
        if bad:
            skipped.append((name, bad))
            continue
        while roles and roles[-1] is None:
            roles.pop()
        if not roles:
            continue
        rows.append((name, roles))
    return rows, skipped, len(callees)


pos = 0
if __name__ == "__main__":
    rows, skipped, total = main()
    mode = sys.argv[1] if len(sys.argv) > 1 else "report"
    if mode == "report":
        print("callees=%d  tabled=%d  skipped=%d" % (total, len(rows), len(skipped)))
        for n, r in rows:
            print("  %-34s %s" % (n, " ".join("%s=%s" % (ARGREGS[i], v) for i, v in enumerate(r) if v)))
        print("--- SKIPPED (no annotation emitted; a wrong term is worse than none) ---")
        for n, why in skipped:
            print("  %-34s %s" % (n, why))
    elif mode == "blob":
        sep = "/*" + "-" * 196 + "*/"
        offs = {"": 0}
        blob = [""]
        pos = 1
        def off(t):
            global pos
            if t not in offs:
                offs[t] = pos
                blob.append(t)
                pos += len(t) + 1
            return offs[t]
        table = []
        for n, r in rows:
            c = off(n)
            cells = [off(v if v else "") for v in (r + [None] * 6)[:6]]
            table.append((c, cells))
        lines = [sep, '#include "x86_arg_roles.h"', "const char x86_argrole_blob[] ="]
        lines += ['    "%s\\0"' % t for t in blob[:-1]] + ['    "%s\\0" ;' % blob[-1]]
        lines += [sep, "const x86_argrole_t x86_argroles[%d] = {" % len(table)]
        lines += ["    { %d, { %s } }," % (c, ", ".join(str(x) for x in cells)) for c, cells in table]
        lines += ["};"]
        cpp = os.path.join(SRC, "templates", "x86", "x86_arg_roles.cpp")
        hdr = os.path.join(SRC, "templates", "x86", "x86_arg_roles.h")
        open(cpp, "w").write("\n".join(lines) + "\n")
        h = open(hdr).read()
        h = re.sub(r"x86_argroles\[\d+\]", "x86_argroles[%d]" % len(table), h)
        open(hdr, "w").write(h)
        print("wrote %s (%d rows, blob %d bytes) and %s" % (cpp, len(table), pos, hdr))
    else:
        for n, r in rows:
            cells = ", ".join('"%s"' % (v if v else "") for v in (r + [None] * 6)[:6])
            print('    { "%s", { %s } },' % (n, cells))
