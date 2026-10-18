#!/usr/bin/env bash
# test_gate_raku_io_path_and_handle_are_typed_values_as_rakudo_has_them.sh -- IO::Path IS A TYPED VALUE AND AN OPEN FILE IS AN IO::Handle: .IO, the path and file tests, slurp / spurt / lines / words, open and the handle methods, dir, copy, rename, unlink, mkdir
# (row raku-every-suite-to-100-under-nonet-ceo-1266; measured: a 48-expression IO probe against Rakudo differed on 45, and 12 Roast files abort in `open`, 46 + 23 more sit in S32-io / S16-io).
#
# THE DEFECT: `"x".IO` returned nothing, `open` was the SNOBOL4/Icon builtin of the same name ("procedure 'open' has no stackless slab"), a method call on `$*OUT` / `$*ERR` / `$*IN` hit "IR_VAR arg names a local with no LOWER-granted varslot" (the lowerer had no
# case for TT_FH_CAPTURE: the receiver was a valueless SUCCEED wire), and the colon-adverbs of a call (`:append`, `:w`, `:!chomp`) reached the callee as unnamed booleans, so spurt could not tell append from overwrite.
# THE CURE (by_name_dispatch.c, lower_raku.c, rk_tree.c): IO::Path is a typed record IO::Path(path,cwd) built by `.IO` / `$*CWD` / `$*TMPDIR` / `$*HOME` / `$*PROGRAM` / `$*EXECUTABLE` and every path method returns; it
# has the Unix path algebra (basename dirname extension parent child add sibling absolute relative cleanup resolve is-absolute is-relative), the file tests (e f d l r w x rw rwx z s modified accessed changed mode inode), slurp / spurt (:append :createonly) /
# lines (:chomp) / words / open / unlink / mkdir / rmdir / copy / rename / move / chmod / dir, prints as `"p".IO` and stringifies as its path in ~, eq, join and interpolation, and its failures throw X::IO::* (a
# missing file on open or slurp is the X::AdHoc "Failed to open file P: no such file or directory" Rakudo reports). An open file is the existing file-handle value (fh_alloc / g_fh) whose methods are say print put printf flush close opened eof get getc
# lines words slurp readchars seek tell path IO t native-descriptor write; `$*OUT`, `$*ERR`, `$*IN` and the STD names lower through fh_capture. The function forms (open close slurp spurt unlink mkdir rmdir copy rename move chmod dir chdir
# make-temp-file make-temp-dir) lower to one dispatcher __rk_io, also behind __rk_named_call for the named forms; the parser keeps the NAME of a colon-adverb in an IO method call (a pair, not a bare boolean).
# NOT HERE (own rows): .d / .f / .r ... on a missing path answer False (Rakudo returns a Failure that throws when used), the Instant type of .modified (a number here), IO::Spec ($*SPEC), IO::CatHandle, binary reads (Buf), the
# encoding adverbs, IO::Notification, locks, $*PROGRAM keeping the script's extension, pipes and Proc (run, shell).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku; stdout only, stderr is not compared): a scratch directory under /tmp made and removed by the program itself, every method above, the standard handles,
# then the same under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 6a8c31532 before the cure: 8 of 8 witness-mode pairs red (m3 prints nothing, m4 is refused at lowering on the standard-handle method call).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_io_path_and_handle_are_typed_values_as_rakudo_has_them.sh   (~10s, no oracle at run time, no network; writes only under /tmp/rk_iogate_<pid>)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_io_path_and_handle_are_typed_values_as_rakudo_has_them"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W" /tmp/rk_iogate_*' EXIT
cat > "$W/io.raku" <<'EOF'
my $d = "/tmp/rk_iogate_" ~ $*PID;
my $dir = $d.IO;
say $dir.e; $dir.mkdir; say $dir.d; say $dir.e; say $dir.f;
my $f = $dir.child("a.txt");
say $f.Str.ends-with("/a.txt"); say $f.basename; say $f.extension; say $f.parent.Str eq $d;
say $f.e; $f.spurt("hello\nworld\nthree words here\n"); say $f.e; say $f.f; say $f.s; say $f.z;
say $f.slurp.chars; say $f.slurp.lines.elems;
say $f.lines.join("|"); say $f.lines.elems; say $f.words.elems; say $f.words.join(",");
say $f.lines(:!chomp).elems;
$f.spurt("more\n", :append); say $f.lines.join("|");
say slurp($f.Str).chars; say slurp($f).chars;
spurt($dir.child("b.txt").Str, "bee"); say slurp($dir.child("b.txt").Str);
say $dir.child("b.txt").slurp;
my $fh = open($f.Str);
say $fh.get; say $fh.get; say $fh.eof; say $fh.get; say $fh.eof; $fh.close;
$fh = open($f.Str, :r); say $fh.lines.elems; $fh.close;
$fh = open($f.Str); say $fh.slurp.chars; $fh.close;
$fh = open($f.Str); say $fh.readchars(3); say $fh.getc; $fh.close;
my $w = open($dir.child("c.txt").Str, :w); $w.say("one"); $w.print("two"); $w.put("three"); $w.printf("%d-%s\n", 7, "x"); $w.close;
say slurp($dir.child("c.txt").Str);
my $ap = open($dir.child("c.txt").Str, :a); $ap.say("four"); $ap.close; say $dir.child("c.txt").lines.elems;
say $dir.dir.map(*.basename).sort.join(",");
say $f.copy($dir.child("d.txt")); say $dir.child("d.txt").slurp.chars;
say $dir.child("d.txt").rename($dir.child("e.txt")); say $dir.child("d.txt").e; say $dir.child("e.txt").e;
say $dir.child("e.txt").unlink; say $dir.child("e.txt").e;
say $dir.child("nonexistent").unlink;
for <a.txt b.txt c.txt> { $dir.child($_).unlink }
say $dir.dir.elems; say $dir.rmdir; say $dir.e;
say "/a/b/c.txt".IO.dirname; say "/a/b/c.txt".IO.basename; say "c.txt".IO.dirname; say "/".IO.basename; say "a/b/".IO.basename;
say "/a/b/c.txt".IO.extension; say "/a/b/c".IO.extension; say "x.tar.gz".IO.extension;
say "/a/b".IO.is-absolute; say "a/b".IO.is-absolute; say "a/b".IO.is-relative;
say "/a/b".IO.child("c"); say "/a/b/c.txt".IO.parent; say "/a/b/c.txt".IO.parent(2); say "/a/b".IO.sibling("z");
say "a//b/./c".IO.cleanup; say "/a/b".IO.absolute; say "/a/b".IO.relative("/a");
say "/a/b".IO.WHAT; say "/a/b".IO.Str; say "/a/b".IO.gist; say "/a/b".IO.IO.Str;
say "/etc".IO.d; say "/etc/passwd".IO.f; say "/nonexistent".IO.e; say "/tmp".IO.r; say "/tmp".IO.w; say "/etc/passwd".IO.s > 0;
say $*CWD.d; say $*TMPDIR.d; say $*CWD.WHAT;
$*OUT.say("to stdout"); $*OUT.print("p1"); $*OUT.put("p2"); $*ERR.say("to stderr");
my $o = $*OUT; $o.say("via var");
say $*OUT.WHAT;
EOF
cat > "$W/io.ref" <<'EOF'
False
True
True
False
True
a.txt
txt
True
False
True
True
29
False
29
3
hello|world|three words here
3
5
hello,world,three,words,here
3
hello|world|three words here|more
34
34
bee
bee
hello
world
False
three words here
False
4
34
hel
l
one
twothree
7-x

4
a.txt,b.txt,c.txt
True
34
True
False
True
True
False
True
0
True
False
/a/b
c.txt
.
/
b
txt

gz
True
False
True
"/a/b/c".IO
"/a/b".IO
"/a".IO
"/a/z".IO
"a/b/c".IO
/a/b
b
(Path)
/a/b
"/a/b".IO
/a/b
True
True
False
True
True
True
True
True
(Path)
to stdout
p1p2
via var
(Handle)
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
ST=""; for w in io; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in io; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an IO::Path or IO::Handle result that disagrees with Rakudo"
