#!/bin/bash
# lib_mode4_link.sh -- THE ONE MODE-4 LINK LINE (row instruments-no-pie-s1-one-helper-owns-the-mode-4-link-line-and-a-census-counts-the-rest, s1 of
# instruments-the-866-mode-4-link-lines-in-820-harness-scripts-drop-no-pie; R-1536). A gate or a bench that links a SCRIP mode-4 program against the runtime
# sources this file and calls s4e_m4_link. It runs exactly one link and returns that link's rc; it prints nothing of its own, so the caller keeps its own
# redirections around the call. -no-pie stays in the line for now: dropping it is the parent's last step, one line here.
s4e_m4_link() {
    [ $# -ge 3 ] || return 2
    local in="$1" out="$2" rt="$3"
    shift 3
    "${S4E_M4_CC:-gcc}" -m64 -no-pie "$in" -o "$out" -L"$rt" -lscrip_rt -lm -lpthread -Wl,-rpath,"$rt" "$@"
}
