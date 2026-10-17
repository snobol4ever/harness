#!/usr/bin/env bash
# ../harness/scripts/test_gate_send_refuses_a_shell_substituted_body.sh — proves the cure for task
# send-executes-backticks-in-a-message-body-so-the-message-arrives-well-formed-and-wrong: `send` REFUSES
# a body that still carries a literal backtick or $( (argv path AND --stdin heredoc path alike), and an
# ordinary body still sends. Runs against an ISOLATED scratch postoffice (S4E_POST override) so it never
# touches the live shared postoffice or any real seat's inbox.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../SCRIP"
SEND="$ROOT/../harness/scripts/s4e_msg.sh"
PO="$(mktemp -d "${TMPDIR:-/tmp}/s4e_send_gate.XXXXXX")"
trap 'rm -rf "$PO"' EXIT
mkdir -p "$PO/testseat/inbox"
export S4E_POST="$PO" S4E_SEAT=testseat S4E_HOME="$ROOT"
fail=0

msg_file() { ls "$PO/testseat/inbox/"*"-testseat-$1.msg" 2>/dev/null; }

check_refused() { # $1=label $2=topic ; body/heredoc supplied by caller before calling
    local label="$1" topic="$2" rc="$3" f
    f="$(msg_file "$topic")"
    if [ "$rc" -eq 0 ] || [ -n "$f" ]; then
        echo "RED: $label did not refuse (rc=$rc, file=${f:-none})"; fail=1
    else
        echo "ok: $label refused (rc=$rc)"
    fi
}

bash "$SEND" send testseat gate-backtick 'body with a `backtick` inside it' >/tmp/s4e_gate_out.$$ 2>&1
check_refused "argv body with a literal backtick" gate-backtick "$?"

bash "$SEND" send testseat gate-dollarparen 'body with $( inside it' >/tmp/s4e_gate_out.$$ 2>&1
check_refused "argv body with a literal \$(" gate-dollarparen "$?"

bash "$SEND" send testseat gate-stdin-backtick --stdin >/tmp/s4e_gate_out.$$ 2>&1 <<'MSG'
this heredoc line has a `backtick` in it, delimiter was quoted so it survives literally
MSG
check_refused "--stdin body with a literal backtick" gate-stdin-backtick "$?"

out="$(bash "$SEND" send testseat gate-ordinary 'an ordinary message body with no shell metacharacters' 2>&1)"; rc=$?
f="$(msg_file gate-ordinary)"
if [ "$rc" -ne 0 ] || [ -z "$f" ]; then
    echo "RED: an ordinary body did not send (rc=$rc): $out"; fail=1
elif ! grep -qF 'an ordinary message body with no shell metacharacters' "$f"; then
    echo "RED: ordinary body sent but content did not arrive intact: $(cat "$f")"; fail=1
else
    echo "ok: ordinary body still sends, content intact"
fi

rm -f /tmp/s4e_gate_out.$$
if [ "$fail" -ne 0 ]; then echo "RED: send-refuses-shell-substituted-body gate FAILED"; exit 1; fi
echo "GREEN: send refuses a body carrying a backtick or \$( (argv and --stdin alike), and an ordinary body still sends"
