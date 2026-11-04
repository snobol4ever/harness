# lib_runner_out.sh -- box-scheduler step 23 (the cqo, CTO-496): a runner's outputs default under the seat's /tmp/s4e/<seat> and are deleted at the
# verdict. runner_out_default <name> sets OUT to a fresh mktemp -d /tmp/s4e/<seat>/runner_out.<name>.<pid>.XXXXXX and removes it when the runner
# exits (an EXIT trap: the verdict is the runner's last act). An explicit --out DIR is the caller's own and is kept; S4E_KEEP_OUT=1 keeps the default
# and prints where it is. The seat is TMPDIR's when TMPDIR is /tmp/s4e/<seat>, else the root's (util_score_row.derive_measurer, S4E_SEAT overrides).
# util_runner_outputs.py --check reads every runner against this: no output default under a root, and no runner_out.* left by a finished runner.
runner_out_base() {
  case "${TMPDIR:-}" in /tmp/s4e/?*) printf '%s\n' "${TMPDIR%/}"; return 0;; esac
  local s="${S4E_SEAT:-}" h; h="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -n "$s" ] || s="$(S4E_HOME="${S4E_HOME:-$(cd "$h/../.." && pwd)}" python3 -c 'import sys; sys.path.insert(0,sys.argv[1]); import util_score_row as u
print(u.derive_measurer() or "")' "$h" 2>/dev/null)"
  case "$s" in ''|*[!a-z0-9_]*) s="$(id -un)";; esac
  printf '/tmp/s4e/%s\n' "$s"
}
runner_out_end() {
  [ -n "${S4E_RUNNER_OUT_DEL:-}" ] || return 0
  case "$S4E_RUNNER_OUT_DEL" in /tmp/s4e/*/runner_out.*) ;; *) return 0;; esac
  if [ "${S4E_KEEP_OUT:-0}" = 1 ]; then printf 'RUNNER-OUT kept %s (S4E_KEEP_OUT=1)\n' "$S4E_RUNNER_OUT_DEL" >&2; else rm -rf -- "$S4E_RUNNER_OUT_DEL"; fi
}
runner_out_default() {
  local n="${1:?runner_out_default takes a name}" b; b="$(runner_out_base)"
  mkdir -p -m 700 "$b" 2>/dev/null || return 2
  OUT="$(mktemp -d "$b/runner_out.$n.$$.XXXXXX")" || return 2
  S4E_RUNNER_OUT_DEL="$OUT"; trap runner_out_end EXIT
}
