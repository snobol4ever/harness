#!/usr/bin/env bash
# util_graphics_oracles_check.sh [LIB] -- THE GRAPHICS ORACLES DRAW ONE PROBE TWICE ALIKE UNDER PRIVATE DISPLAYS (row oracle-icon-and-unicon-have-a-graphics-build-under-xvfb, officer_06 2026-11-16).
# LIB is lib_oracle_flags.sh (default: the one beside this script). Arizona (graphics_icont_bin, graphics_iconx_bin) and unicon (graphics_unicon_bin) each translate the probe below and run it twice
# through graphics_display_run, the four runs at once (so the -displayfd road is shown free of a race); each oracle's two texts and two GIFs must be byte equal, the two oracles' texts must agree
# apart from unicon's "3D graphics" feature line, and with no display each must answer "no window". rc 0 GREEN, rc 1 RED (named), rc 2 REFUSAL (an oracle or Xvfb missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${1:-$HERE/lib_oracle_flags.sh}"
. "$LIB" || { echo "REFUSED(2) [util_graphics_oracles_check]: cannot source $LIB"; exit 2; }
for f in graphics_icont_bin graphics_iconx_bin graphics_unicon_bin graphics_display_run; do declare -F $f > /dev/null || { echo "RED [util_graphics_oracles_check]: $LIB defines no $f"; exit 1; }; done
command -v Xvfb > /dev/null 2>&1 || { echo "REFUSED(2) [util_graphics_oracles_check]: no Xvfb on PATH"; exit 2; }
IT="$(graphics_icont_bin)" && IX="$(graphics_iconx_bin)" && UN="$(graphics_unicon_bin)" || { echo "REFUSED(2) [util_graphics_oracles_check]: a graphics oracle is missing"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gfx_check.XXXXXX")" || exit 2; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/icon" "$W/unicon"
cat > "$W/icon/probe.icn" <<'ICN'
link graphics
procedure main()
   local w, x, y, s, f;
   every f := &features do if f == ("graphics" | "X Windows" | "3D graphics") then write("feature: ", f);
   w := WOpen("size=64,48", "bg=white", "fg=black") | stop("no window");
   write("type: ", type(w));
   write("size: ", WAttrib(w, "width"), "x", WAttrib(w, "height"));
   write("fg: ", Fg(w), " bg: ", Bg(w));
   Fg(w, "red");
   DrawLine(w, 0, 0, 63, 47);
   FillRectangle(w, 40, 4, 16, 10);
   Fg(w, "blue");
   DrawCircle(w, 20, 30, 10);
   WFlush(w);
   every y := 0 to 47 by 6 do {
      s := "";
      every x := 0 to 63 by 4 do s ||:= (case Pixel(w, x, y, 1, 1) of { "65535,65535,65535": "."; "65535,0,0": "R"; "0,0,65535": "B"; default: "?" });
      write(s);
   };
   WriteImage(w, "probe.gif");
   WClose(w);
   write("done");
end
ICN
cp "$W/icon/probe.icn" "$W/unicon/probe.icn"
( cd "$W/icon" && timeout -k 5 60 "$IT" -s probe.icn < /dev/null ) > /dev/null 2>&1 || { echo "RED [util_graphics_oracles_check]: icont refused the probe"; exit 1; }
( cd "$W/unicon" && timeout -k 5 60 "$UN" -s probe.icn -o probe.uni < /dev/null ) > /dev/null 2>&1 || { echo "RED [util_graphics_oracles_check]: unicon refused the probe"; exit 1; }
for o in icon unicon; do for i in 1 2; do mkdir -p "$W/$o/r$i"; done; done
for i in 1 2; do
    ( cd "$W/icon/r$i" && graphics_display_run timeout -k 5 60 "$IX" ../probe < /dev/null > out.txt 2>&1; echo "rc=$?" >> out.txt ) &
    ( cd "$W/unicon/r$i" && graphics_display_run timeout -k 5 60 ../probe.uni < /dev/null > out.txt 2>&1; echo "rc=$?" >> out.txt ) &
done
wait
bad=0
for o in icon unicon; do
    grep -qx done "$W/$o/r1/out.txt" && grep -qx rc=0 "$W/$o/r1/out.txt" || { echo "RED [util_graphics_oracles_check]: $o did not draw:"; cat "$W/$o/r1/out.txt"; bad=1; }
    cmp -s "$W/$o/r1/out.txt" "$W/$o/r2/out.txt" || { echo "RED [util_graphics_oracles_check]: $o text differs between two runs"; bad=1; }
    [ -s "$W/$o/r1/probe.gif" ] && cmp -s "$W/$o/r1/probe.gif" "$W/$o/r2/probe.gif" || { echo "RED [util_graphics_oracles_check]: $o GIF absent or differs between two runs"; bad=1; }
    echo "GRAPHICS_ORACLE $o text $(md5sum < "$W/$o/r1/out.txt" | cut -c1-32) gif $(md5sum < "$W/$o/r1/probe.gif" 2> /dev/null | cut -c1-32) features $(grep '^feature: ' "$W/$o/r1/out.txt" | sed 's/^feature: //' | paste -sd, -)"
done
diff <(grep -vx 'feature: 3D graphics' "$W/icon/r1/out.txt") <(grep -vx 'feature: 3D graphics' "$W/unicon/r1/out.txt") > /dev/null || { echo "RED [util_graphics_oracles_check]: the two oracles disagree on the probe"; bad=1; }
nd_i="$(cd "$W/icon" && env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY timeout -k 5 30 "$IX" probe < /dev/null 2>&1 | tail -1)"
nd_u="$(cd "$W/unicon" && env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY timeout -k 5 30 ./probe.uni < /dev/null 2>&1 | tail -1)"
[ "$nd_i" = "no window" ] && [ "$nd_u" = "no window" ] || { echo "RED [util_graphics_oracles_check]: with no display icon [$nd_i] unicon [$nd_u], want no window"; bad=1; }
[ "$bad" = 0 ] && { echo "GREEN [util_graphics_oracles_check]: both graphics oracles draw the probe twice alike under private displays"; exit 0; }
exit 1
