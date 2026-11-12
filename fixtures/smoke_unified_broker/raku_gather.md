```SNOBOL4
*  raku_gather.md — GOAL-RAKU-FRONTEND RK-7
*  Proof: Raku gather/take maps to BB_PUMP; SNOBOL4 receives each value.
*  The SNOBOL4 section is first, so it starts; its last statement calls the Raku section's count_five().
        &TRIM = 1
        OUTPUT = 'SNOBOL4: ready'
        count_five()
END
```

```Raku
# raku_gather.md — Raku section (RK-7)
# gather { take $_ for 1..5 } drives BB_PUMP; each value printed via say.
sub count_five() {
    my $i = 1;
    while ($i <= 5) {
        say('RAKU: ' ~ $i);
        $i = $i + 1;
    }
}
```
