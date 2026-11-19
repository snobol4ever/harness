#!/bin/bash
# funcsweep.sh FUNC NARGS : write FUNC.sno (funcgen.py), run it under sbl -bf and under the dotnet console, and diff the two
# Run it from an empty scratch directory. SBL and DLL may be set in the environment.
here=$(cd "$(dirname "$0")" && pwd)
repo=${S4E_DOTNET_ROOT:-/home/claude_dotnet}
SBL=${SBL:-/home/resources/x64/bin/sbl}
DLL=${DLL:-$repo/Snobol4/bin/Release/net10.0/Snobol4.dll}
f=$1; n=$2
python3 -I "$here/funcgen.py" "$f" "$n" >/dev/null
timeout 120 "$SBL" -bf "$f.sno" </dev/null > "$f.sbl" 2>&1
timeout 120 dotnet "$DLL" -bf "$f.sno" </dev/null > "$f.net" 2>&1
if cmp -s "$f.sbl" "$f.net"; then echo "$f/$n: IDENTICAL ($(wc -l < "$f.sbl") lines)"
else echo "$f/$n: DIFFERS $(diff "$f.sbl" "$f.net" | grep -c '^<') lines"; diff "$f.sbl" "$f.net" | head -${N:-8}; fi
