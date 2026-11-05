#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
# test_gate_icon_cset_literal_is_read_by_its_header_not_registered_by_a_call.sh -- AN ICON CSET LITERAL IS A STATIC BLOCK WHOSE LENGTH AND BITS LIVE IN ITS OWN HEADER; NOTHING REGISTERS IT AT RUN TIME
# (row icon-the-startup-rebuilds-compile-time-tables-procedures-csets-globals-registered-by-c-calls-at-run-time-r-1969, slice 3).
# ⛔ THE MEASURED DEFECT: bb_lit_charset emitted push/push/call rt_icn_cset_register/pop/pop and a GC poll inside every cset literal's alpha (49 sites over the 17 Icon benchmarks), and the call appended (ptr, len)
# to the address-keyed registry kw_cset_names so that kw_cset_len(ptr) and kw_cset_bits(ptr) could answer "is this exact address a cset, how long, which bits". Scanning-asm step 2b-1 already made every literal a
# header-carrying block (.cset_hdr: int32 length at p-40, magic 0xC5E7B175 at p-36, the 32-byte table at p-32). A reader that holds a cset DESCRIPTOR (slen 0xFFFFFFFF) therefore reads the header and needs no
# registry; a reader that holds a plain string pointer must NEVER read p-36 (it may precede a mapping, and a crafted substring whose preceding bytes are 75 B1 E7 C5 would forge the magic), so it takes the
# length from its own descriptor and computes the bits from the chars. The same sweep replaces the strlen in the table-key length (aggregates.c _tbl_slen), which made the NUL-bearing cset 'a\x00b' collide with
# the empty cset as a table key (the length is carried, never measured).
# FIVE ARMS. STATIC: every Icon benchmark in mode 4 has no call to rt_icn_cset_register and exactly as many .cset_hdr blocks (a quad whose high word is the magic) as the IR has LIT_CHARSET nodes. EXPORTS:
# out/libscrip_rt.so defines none of rt_icn_cset_register, kw_cset_len, kw_cset_bits (the raw-pointer readers are gone, not merely uncalled). CONSTRUCTORS: every CSETVAL( in the runtime (the tests aside) is
# built from a block source (kw_cset_names, kw_cset_empty, cset_canonical, the interned result ur, the freshly made block), so no cset descriptor points at a plain string a header read would trust.
# BEHAVIOURAL: one witness (literals of 0, 3, 26, 62 and 16 chars, a NUL-bearing one, the keyword csets, ++ -- ** ~ === image * string cset() any many upto upto-in-scan, subscripts and sections, table and set
# keys, and substrings whose preceding bytes forge the magic) run in BOTH modes byte-equal to the oracle (Arizona icont 9.5.25a), the oracle's output carrying the lines compared.
# FAIL-ONCE: STATIC, EXPORTS and the table-key line of BEHAVIOURAL are red on SCRIP 6e556e03b (49 emitted calls, the three symbols exported, 'a\x00b' = '' as a key). No plant anywhere in src/.
# Board line: ICON_CSET_READERS_BOARD programs=<p> register_calls=<n> headers=<h> ir_literals=<l> exports=<ok|bad> ctor=<ok|bad> m3=<same|differs> m4=<same|differs> (tree <hash>)
# rc 0 all arms green · rc 1 an arm red, named · rc 2 cannot measure (no oracle, no corpus benchmarks, a program did not compile, the witness did not build).
NAME=icon_cset_literal_is_read_by_its_header_not_registered_by_a_call
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(pwd)"
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
ICONT="$(icont_bin)" || refuse "no icont oracle (lib_oracle_flags icont_bin) -- a missing oracle prints a full, plausible, entirely false all-FAIL table"
ICONX="$(iconx_bin)" || refuse "no iconx oracle (lib_oracle_flags iconx_bin)"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so missing -- run make"
BENCH="$ROOT/../corpus/benchmarks/icon"
ls "$BENCH"/*.icn >/dev/null 2>&1 || refuse "no Icon benchmarks at $BENCH (a sparse corpus needs benchmarks/icon)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/hdrs.py" <<'EOS'
import re, sys
n = 0
for l in open(sys.argv[1], encoding='utf-8', errors='replace'):
    m = re.match(r'^\s*\.quad\s+(\d+)\s*$', l)
    if m and (int(m.group(1)) >> 32) == 0xC5E7B175: n += 1
print(n)
EOS
bad=0; progs=0; regs=0; hdrs=0; lits=0
for f in "$BENCH"/*.icn; do
    timeout -k 5 120 ./scrip --compile --out="$W/b.s" "$f" < /dev/null >/dev/null 2>&1 || refuse "$(basename "$f") did not compile in mode 4 -- the count would not cover the population"
    timeout -k 5 120 ./scrip --dump-ir "$f" < /dev/null > "$W/b.ir" 2>/dev/null || refuse "$(basename "$f") has no --dump-ir"
    progs=$((progs + 1))
    n=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?rt_icn_cset_register\b' "$W/b.s"); regs=$((regs + n))
    h=$(python3 -I "$W/hdrs.py" "$W/b.s"); l=$(grep -cE '^[0-9]+@?[[:space:]]+[0-9.]+@?[[:space:]]+[0-9.]+@?[[:space:]]+LIT_CHARSET[[:space:]]' "$W/b.ir")
    hdrs=$((hdrs + h)); lits=$((lits + l))
    [ "$h" -eq "$l" ] || { bad=1; echo "  STATIC RED: $(basename "$f"): $h .cset_hdr block(s) for $l LIT_CHARSET node(s) -- every literal must carry its header"; }
done
[ "$lits" -gt 0 ] || refuse "no LIT_CHARSET node over $progs benchmarks -- the census would be empty"
if [ "$regs" -ne 0 ]; then echo "  STATIC RED: $regs emitted call(s) to rt_icn_cset_register over $progs Icon benchmarks -- a literal is read by its header, never registered"; bad=1; fi
ex=ok
for sym in rt_icn_cset_register kw_cset_len kw_cset_bits; do
    if nm -D --defined-only "$ROOT/out/libscrip_rt.so" 2>/dev/null | grep -qE " $sym\$"; then ex=bad; bad=1; echo "  EXPORTS RED: libscrip_rt.so still defines $sym"; fi
done
ctor=ok
while IFS= read -r ln; do
    case "$ln" in
        *"kw_cset_names["*|*"kw_cset_empty()"*|*"cset_canonical("*|*"CSETVAL(stable)"*|*"CSETVAL(outlen > 0 ? ur"*|*"define CSETVAL"*) ;;
        *) ctor=bad; bad=1; echo "  CONSTRUCTORS RED: a cset descriptor is built from something that is not a block source: $ln";;
    esac
done < <(grep -rn 'CSETVAL(' "$ROOT/src" --include=*.c --include=*.h --include=*.cpp | grep -v -E '_test\.c:' | sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//')
cat > "$W/w.icn" <<'EOS'
procedure show(label, c);
    write(label, " ", *c, " ", image(c), " ", *string(c));
    return;
end
procedure probe(label, c, s);
    local p;
    write(label, " any=", any(c, s) | "-", " many=", many(c, s) | "-", " upto=", upto(c, s) | "-", " find1=", (s ? (tab(upto(c)) & &pos)) | "-");
    s ? { p := []; while tab(upto(c)) do { put(p, &pos); move(1) }; write(label, " all=", *p) };
    return;
end
procedure main();
    local a, b, c, d, e, f, g, m, s, t, u, k, tb, st, i, forged;
    a := 'abc';
    b := '';
    c := 'a\x00b';
    d := 'abcdefghijklmnopqrstuvwxyz';
    e := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    f := '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f';
    show("a", a); show("b", b); show("c", c); show("d", d); show("e", e); show("f", f);
    show("lc", &lcase); show("cs", &cset); show("asc", &ascii);
    show("u1", a ++ c); show("u2", c ++ f); show("u3", d ++ 'XYZ'); show("u4", &lcase ++ c);
    show("d1", e -- d); show("d2", c -- a); show("d3", a -- b); show("d4", &cset -- c);
    show("i1", e ** d); show("i2", c ** a); show("i3", a ** b); show("i4", &cset ** f);
    show("n1", ~a); show("n2", ~c); show("n3", ~~f); show("n4", ~&cset); show("n5", ~b);
    write(a === 'abc', " ", (d ++ 'z') === d, " ", (&lcase -- 'z') ++ 'z' === d, " ", c === ('a' ++ '\x00' ++ 'b'), " ", d === &lcase);
    write(*c, " ", *f, " ", *(c ++ f), " ", *~c, " ", *&cset);
    write(image(c), " ", image(f), " ", image(b));
    probe("pa", a, "xxaxbxxcx");
    probe("pc", c, "xx\x00xaxbx\x00");
    probe("pd", d, "123 hello World 456");
    probe("pe", e, "--%% x7 --");
    probe("pf", f, "ab\x00\x01cd\x0f");
    probe("pb", b, "abc");
    write(a[1], " ", a[2:4], " ", c[2], " ", (c[3] == "b") | "nob", " ", d[26], " ", e[-1], " ", f[16] === "\x0f");
    every write(!a);
    every write(ord(!c));
    write(string(c) == "\x00ab", " ", *string(c));
    write(*cset("hello"), " ", cset("hello") === cset("olleh"), " ", cset(a) === a, " ", cset(c) === c);
    s := ""; every s ||:= !a; write(s);
    m := set(); every insert(m, !c); write(*m);
    tb := table(0); every tb[!d] +:= 1; write(*tb);
    st := sort(m); write(*st, " ", ord(st[1]), " ", ord(st[2]), " ", ord(st[3]));
    tb := table(); tb[a] := 1; tb[d] := 2; tb[c] := 3; tb[b] := 4; write(*tb, " ", tb['abc'], " ", tb[&lcase], " ", tb[c], " ", tb['']);
    every i := 1 to 3 do write(("x" || a) ? (tab(upto(a)) & move(i) & (&pos + 0)) | "none");
    forged := char(16r75) || char(16rB1) || char(16rE7) || char(16rC5) || repl("q", 32) || "abc" || "xyz";
    u := forged[37:0];
    write(*u, " ", u, " ", any(u, "a") | "-", " ", any(u, "q") | "-", " ", many(u, "xyzabc") | "-", " ", upto(u, "zzzcz") | "-");
    write(*cset(u), " ", image(cset(u)), " ", *(u ++ "z"), " ", *(u -- "a"), " ", *(u ** "ab"), " ", *~u);
    u := forged[37:40];
    write(*u, " ", image(cset(u)), " ", *(u ++ "q"), " ", any(u, "b") | "-", " ", upto(u, "zzc") | "-");
    u := (repl("z", 8) || forged)[9:0];
    write(image(cset(u[37:0])), " ", *(u[37:0] ++ cset("z")));
    u := forged[5:37];
    write(*cset(u), " ", image(cset(u)), " ", many(u, "qqqq") | "-");
    u := (char(16r75) || char(16rB1) || char(16rE7) || char(16rC5) || repl("\x00", 32) || "k");
    write(*cset(u[37:0]), " ", image(cset(u[37:0])), " ", *(u[37:0] ++ "k"), " ", any(u[37:0], "k") | "-");
end
EOS
( cd "$W" && "$ICONT" -s -o oracle_bin w.icn >/dev/null 2>&1 ) || refuse "the oracle did not build the witness"
( cd "$W" && timeout -k 5 60 "$ICONX" oracle_bin < /dev/null > oracle.out 2>&1 ) || refuse "the oracle did not run the witness to rc 0"
[ "$(wc -l < "$W/oracle.out")" -ge 60 ] || refuse "the oracle's output is $(wc -l < "$W/oracle.out") lines -- the comparison would be nearly empty"
for k in "a 3 'abc' 3" "lc 26 &lcase 26" "cs 256 &cset 256" "4 1 2 3 4" "6 'abcxyz' 6 5 2 250"; do
    grep -qaxF -- "$k" "$W/oracle.out" || refuse "the oracle's output lacks the line [$k]: the comparison would be empty against empty"
done
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" w.icn < /dev/null > m3.out 2>&1 )
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out=w.s w.icn < /dev/null >/dev/null 2>&1 && gcc w.s -o w4 -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || refuse "the witness did not build in mode 4"
( cd "$W" && timeout -k 5 60 ./w4 < /dev/null > m4.out 2>&1 )
m3=same; m4=same
cmp -s "$W/oracle.out" "$W/m3.out" || { m3=differs; bad=1; echo "  BEHAVIOURAL RED: mode 3 differs from the oracle:"; diff -a "$W/oracle.out" "$W/m3.out" | head -8; }
cmp -s "$W/oracle.out" "$W/m4.out" || { m4=differs; bad=1; echo "  BEHAVIOURAL RED: mode 4 differs from the oracle:"; diff -a "$W/oracle.out" "$W/m4.out" | head -8; }
echo "ICON_CSET_READERS_BOARD programs=$progs register_calls=$regs headers=$hdrs ir_literals=$lits exports=$ex ctor=$ctor m3=$m3 m4=$m4 (tree $(git rev-parse --short HEAD))"
[ "$bad" = 0 ] && { echo "GATE OK [$NAME]: $progs benchmarks carry $lits cset literals as header blocks, no registration call, and every reader agrees with the oracle"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
