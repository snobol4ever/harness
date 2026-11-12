```SNOBOL4
*  cross_lang.md — GOAL-UNIFIED-BROKER U-19
*  Proof: all three bb_broker modes active in one polyglot --run.
*
*  SNOBOL4 section: bb_broker(BB_SCAN) — pattern match drives subject scan.
*  Counts matches of 'x' in a string; each iteration is one BB_SCAN tick.
        &TRIM = 1
        str   = 'axbxcx'
        n     = 0
next    str   'x' =             :F(done)
        n     = n + 1           :(next)
done    OUTPUT = 'SNO: ' n
        icn_count()
        pl_colors()
END
```

```Icon
#  cross_lang.md — Icon section
#  bb_broker(BB_PUMP) — icn_eval_gen builds a bb_node_t for (1 to 3);
#  bb_broker drives it, yielding each integer until omega.
procedure icn_count()
    every write("ICN: " || (1 to 3));
end
```

```Prolog
%  cross_lang.md — Prolog section
%  bb_broker(BB_ONCE) — pl_box_choice + bb_broker drives each clause.
%  Three color facts; pl_colors/0 uses a fail-loop to enumerate all via backtracking.
color(red).
color(green).
color(blue).
pl_colors :- color(X), write('PL: '), write(X), nl, fail.
pl_colors.
```
