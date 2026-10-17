#!/usr/bin/env bash
# util_unload_of_a_running_procedure_answers_like_spitbol.sh -- the DONE-WHEN of row snobol4-unload-of-a-running-procedure-loses-its-return-
# value-and-never-restores-its-formals (ceo 2026-09-25): a function that UNLOADs itself returns its value and restores its formal on return,
# as sbl -bf does, in m3 and m4; a redefinition inside the body and an APPLY are the controls. rc 0 / 1 red / 2 could not run.
R="${S4E_HOME:-/home/claude_ceo}/SCRIP"; W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W" || exit 2
cat > u.sno <<'SNO'
        X = 'global'
        DEFINE('F(X)')                                  :(FEND)
F       UNLOAD('F')
        F = X '!'                                       :(RETURN)
FEND    OUTPUT = F('arg')
        OUTPUT = X
        DEFINE('G(X)')                                  :(GEND)
G       G = X '?'                                       :(RETURN)
GEND    OUTPUT = APPLY('G', 'viaapply')
        OUTPUT = X
        DEFINE('H(X)')                                  :(HEND)
H       DEFINE('H(X,Y)')
        H = X '#'                                       :(RETURN)
HEND    OUTPUT = H('first')
        OUTPUT = X
        OUTPUT = H('second', 'y')
        OUTPUT = X
END
SNO
want="$(/home/resources/x64/bin/sbl -bf u.sno < /dev/null 2>/dev/null)"; [ -n "$want" ] || exit 2
m3="$(timeout -k 5 30 "$R/scrip" u.sno < /dev/null 2>/dev/null)"
"$R/scrip" --compile -o u.s u.sno < /dev/null > /dev/null 2>&1 && gcc u.s -L"$R/out" -lscrip_rt -lm -Wl,-rpath,"$R/out" -o u.bin 2>/dev/null || exit 2
m4="$(timeout -k 5 30 ./u.bin < /dev/null 2>/dev/null)"
[ "$m3" = "$want" ] && [ "$m4" = "$want" ] && { echo "GREEN: a procedure that unloads itself returns and restores its formal like the oracle, in m3 and m4"; exit 0; }
echo "RED: oracle [$(echo $want)] m3 [$(echo $m3)] m4 [$(echo $m4)]"; exit 1
