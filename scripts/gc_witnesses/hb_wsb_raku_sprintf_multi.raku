#  WITNESS for the by_name_dispatch.c rk_sprintf_core buffer chain (HB_WSB, ATOMIC) and the
#  rt_multi_meth_dispatch argument vector (HB_DVEC, a DESCR array).
#  The sprintf buffer GROWS by allocate-and-memcpy rather than in place, so each growth step mints a
#  fresh block and abandons the previous one: a collector that scanned the atomic buffer's interior, or
#  lost its forwarding address, corrupts TEXT rather than crashing.  The dispatch vector is the opposite
#  kind -- every slot is a live DESCR, including the invocant and a heap string argument -- so the two
#  halves of this witness probe the two opposite walker decisions in one program.
class Holder {
    multi method tag(Int $n) { return sprintf("int<%05d>", $n); }
    multi method tag(Str $s) { return sprintf("str<%s>", $s); }
}
my $h = Holder.new;
my $wide = "x" x 600;
my $mid  = "y" x 300;
my $a = sprintf("%s", $wide);
my $b = sprintf("%s and then a good deal of literal tail text to push past the capacity", $mid);
my $c = sprintf("%b|%b|%b", 5, 255, 1024);
my $d = sprintf("%08b|%05d|%.3f|%x", 5, 42, 3.14159, 255);
my $e = $h.tag(7);
my $f = $h.tag("held");
my $churn = "";
for 1 .. 300 { $churn = sprintf("%s%d", $churn, 1); }
say $a.chars;
say $b.chars;
say $c;
say $d;
say $e;
say $f;
say $churn.chars;
say $h.tag($c);
