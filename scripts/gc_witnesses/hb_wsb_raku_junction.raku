#  WITNESS for the by_name_dispatch.c NESTED-junction member copy -- junction_collapse's member block is
#  HB_WSB (ATOMIC): a memcpy of the nested member's bytes plus a NUL, handed straight to STRVAL and dead
#  at the return.  The nested arm is the one that allocates; a flat junction never reaches it.
#  ⛔ Every comparison is forced into BOOLEAN context with so(): a bare `say 2 == any(...)` AUTOTHREADS in
#  real Raku and prints the junction of Bools, so a ref cut that way would grade the printer, not the collapse.
my $n = any(any(1, 2), 3);
my $s = any(any("aa", "bb"), "cc");
say so(2 == $n);
say so(7 == $n);
say so("bb" eq $s);
say so("zz" eq $s);
my $t = "";
for 1 .. 400 { $t = $t ~ "x"; }
say so(3 == $n);
say so("cc" eq $s);
say $t.chars;
