# lib_raku_bench_wrap.sh -- ONE AUTHORITY for turning a self-timed Raku kernel into an N-times-looped
# derived twin, sourced by test_bench_raku_timed.sh (angle 1) and bench_raku_fixed_iter.sh (angle 2) so the
# transform never drifts into two copies (RULES.md FACT RULES precedent: lib_perf_fmt.sh / lib_oracle_flags.sh).
#
# ⛔ WHY THIS IS NOT A ONE-LINE sed, UNLIKE PROLOG'S mkwrap(): Raku kernels are top-level scripts, not named
# predicates, so there is no clause head to rename -- the loop body is exactly the region the kernel's OWN
# self-timing bracket already delimits (between "my $t0 = wall_us(); my $m0 = wall_ms();" and
# "my $t1 = wall_us(); my $m1 = wall_ms();", the WORK per RULES.md § THE TWO-NUMBER BENCHMARK BASIS).
# Naively wrapping that span in `for 1..N { ... }` is WRONG: Raku's `{}` introduces a fresh lexical scope
# every iteration, so any `my $x = ...` declared inside the bracket that the kernel's OWN post-bracket code
# reads (e.g. point_class_add1's `print $a.x, ...` after the loop, where $a is declared INSIDE the bracket)
# goes out of scope the moment the loop body's `}` closes -- Rakudo refuses to compile the naive wrap with
# "Variable '$x' is not declared", measured live the first time this was tried (KERNELS=string-escape: $s is
# used by `say $s.chars;` after the bracket but declared with `my` inside it).
#
# THE FIX: raku_bench_wrap() scans the bracket for top-level `my [Type] $var = ...;` declarations, and for
# each one whose `$var` is referenced ANYWHERE after the bracket closes (word-boundary matched, not a bare
# substring -- `$s` must not match inside a hypothetical `$send`), HOISTS it: declares `my [Type] $var;`
# immediately before the `for` loop opens, and rewrites the in-loop occurrence to a plain assignment (no
# `my`, no type). A declaration whose variable never leaks past the bracket is left exactly as written and
# is redeclared fresh every iteration -- correct either way, since nothing outside the loop can observe it.
# Verified against all 4 currently self-timed kernels: point_class_add[1] hoists $a (not $i, not $b),
# string-escape hoists $s (not $d -- and the multi-line `.trans(...)` continuation is untouched, since only
# the DECLARING line carries `my`), send-more-money-loops hoists nothing (nothing declared in its bracket is
# read after it -- its own `say` fires INSIDE the bracket; `note()` after it names no bracket-local var).
#
# USAGE: raku_bench_wrap <src.raku> <N> <out.raku>
raku_bench_wrap() {
  local src="$1" n="$2" out="$3"
  awk -v n="$n" \
      -v wopen='$t0 = wall_us(); my $m0 = wall_ms();' \
      -v wclose='$t1 = wall_us(); my $m1 = wall_ms();' '
    { lines[NR] = $0 }
    END {
      open_ln = 0; close_ln = 0
      for (i = 1; i <= NR; i++) {
        if (open_ln == 0 && index(lines[i], wopen) > 0) open_ln = i
        else if (open_ln != 0 && close_ln == 0 && index(lines[i], wclose) > 0) close_ln = i
      }
      if (open_ln == 0 || close_ln == 0) {
        for (i = 1; i <= NR; i++) print lines[i]      # no bracket found -- pass through, caller decides
        exit
      }
      post = ""
      for (i = close_ln + 1; i <= NR; i++) post = post "\n" lines[i]

      for (i = 1; i <= open_ln; i++) print lines[i]   # setup, through and including the $t0/$m0 capture line

      decl_re = "^[ \t]*my[ \t]+(([A-Za-z_][A-Za-z0-9_:]*)[ \t]+)?\\$([A-Za-z_][A-Za-z0-9_]*)[ \t]*="
      hoist_text = ""
      for (i = open_ln + 1; i < close_ln; i++) {
        if (match(lines[i], decl_re)) {
          mstr = substr(lines[i], RSTART, RLENGTH)      # e.g. "    my Point $a ="
          rest = mstr; sub(/^[ \t]*my[ \t]+/, "", rest)  # "Point $a =" or "$a ="
          typepart = rest; sub(/\$.*/, "", typepart); gsub(/[ \t]+$/, "", typepart)   # "Point" or ""
          vpart = rest; sub(/^[^$]*\$/, "", vpart)       # "a ="
          varname = vpart; sub(/[ \t]*=.*/, "", varname) # "a"
          needle = "\\$" varname "([^A-Za-z0-9_]|$)"
          if (post ~ needle) {
            leaks[i] = 1; vname[i] = varname
            tail[i] = substr(lines[i], RSTART + RLENGTH)  # everything after the matched "...=" (incl. leading space)
            hoist_text = hoist_text "my " (typepart != "" ? typepart " " : "") "$" varname ";\n"
          }
        }
      }
      printf "%s", hoist_text
      print "for 1.." n " {"
      for (i = open_ln + 1; i < close_ln; i++) {
        if (leaks[i]) print "$" vname[i] " =" tail[i]
        else print lines[i]
      }
      print "}"
      for (i = close_ln; i <= NR; i++) print lines[i]
    }
  ' "$src" > "$out"
}
