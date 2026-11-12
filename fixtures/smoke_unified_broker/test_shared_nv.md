```SNOBOL4
*  test_shared_nv.md — GOAL-UNIFIED-BROKER U-23
*  Proof: SNO NV store shared across all language sections.
*
*  SNO sets SHARED_VAL='hello' and COUNTER=0.
*  Icon reads SHARED_VAL via `global` declaration (U-23 bridge),
*  updates COUNTER to 42 via global, and writes both.
*  Prolog reads SHARED_VAL via nv_get/2 and sets MSG via nv_set/2.
*
*  Expected output:
*    SNO: SHARED_VAL=hello
*    SNO: COUNTER=0
*    ICN reads SHARED_VAL: hello
*    ICN: COUNTER now 42
*    PL reads SHARED_VAL: hello
*    PL sets MSG=from_prolog
        &TRIM = 1
        SHARED_VAL = 'hello'
        COUNTER = 0
        OUTPUT = 'SNO: SHARED_VAL=' SHARED_VAL
        OUTPUT = 'SNO: COUNTER=' COUNTER
        icn_shared()
        pl_shared()
END
```

```Icon
global SHARED_VAL
global COUNTER
procedure icn_shared()
    write("ICN reads SHARED_VAL: " || SHARED_VAL);
    COUNTER := 42;
    write("ICN: COUNTER now " || COUNTER);
end
```

```Prolog
%  Prolog reads SHARED_VAL via nv_get and writes MSG via nv_set
pl_shared :-
    nv_get('SHARED_VAL', V),
    write('PL reads SHARED_VAL: '), write(V), nl,
    nv_set('MSG', 'from_prolog'),
    write('PL sets MSG=from_prolog'), nl.
```
