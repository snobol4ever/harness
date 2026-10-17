#!/usr/bin/env python3
# s4e_install_inbox_hook.py -- install THE LOOP step 1 as a UserPromptSubmit hook in THIS seat's
# .claude/settings.json.  Idempotent, merge-not-clobber, backs up first, seat-derived.
#
# WHY A SCRIPT AND NOT AN EDIT.  The harness permission classifier refuses to let the model write
# .claude/settings.json by ANY tool (shell heredoc, editor, whole-file write -- all three tried and
# refused at s261), because a hook is arbitrary code the harness executes on every prompt and a model
# may not install one for itself.  That refusal is correct and is not routed around here: this script
# only RUNS when a human runs it.  Lon runs `! python3 harness/scripts/s4e_install_inbox_hook.py` and the
# authority is his, which is exactly where it belongs.
#
# WHAT IT INSTALLS AND WHY.  ../harness/scripts/s4e_inbox_hook.sh prints the seat's unread count and the FROM/RE
# line of each message, at every prompt, mechanically.  MEASURED at s261: both HQs ran `s4e_msg.sh
# check` exactly ONCE at session start, read ten messages, replied to none, cleared neither, and never
# looked again -- messages arrived unseen mid-session including a request for a receipt.  PROTOCOL.md
# says "At EVERY prompt, before anything else"; nothing enforced it.  The BANNER law had this identical
# defect ("MANDATORY LAST ACT OF EVERY SESSION" -- unfollowable, since no session knows which reply is
# its last) and Lon's cure there was a Stop hook, not a sterner rule.  This is that cure for step 1.
import json, os, shutil, sys
seat_root = os.environ.get("S4E_HOME") or os.path.dirname(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"))
hook_sh = os.path.join(seat_root, "SCRIP", "scripts", "s4e_inbox_hook.sh")
settings = os.path.join(seat_root, ".claude", "settings.json")
if not os.path.exists(hook_sh):
    sys.exit("REFUSED: %s does not exist -- pull SCRIP first (landed 3970f54a)." % hook_sh)
cmd = ("out=$(timeout -k 5 20 bash %s 2>&1); printf '%%s' \"$out\" | python3 -c "
       "'import json,sys; print(json.dumps({\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\","
       "\"additionalContext\":sys.stdin.read()}}))'" % hook_sh)
entry = {"hooks": [{"type": "command", "command": cmd, "timeout": 30,
                    "statusMessage": "Checking %s inbox" % os.path.basename(seat_root)}]}
os.makedirs(os.path.dirname(settings), exist_ok=True)
cfg = {}
if os.path.exists(settings):
    with open(settings) as f:
        txt = f.read().strip()
    if txt:
        try:
            cfg = json.loads(txt)
        except Exception as e:
            sys.exit("REFUSED: %s is not valid JSON (%s). Fix it first -- a malformed settings file "
                     "silently disables EVERY setting in it, which is a false green of its own." % (settings, e))
    shutil.copyfile(settings, settings + ".bak")
hooks = cfg.setdefault("hooks", {})
ups = hooks.setdefault("UserPromptSubmit", [])
for grp in ups:                                     # idempotent: replace our entry, never stack duplicates
    for h in grp.get("hooks", []):
        if "s4e_inbox_hook.sh" in h.get("command", ""):
            h.update(entry["hooks"][0]); break
    else:
        continue
    break
else:
    ups.append(entry)
with open(settings, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
n_stop = len(hooks.get("Stop", []))
print("INSTALLED  %s" % settings)
print("  UserPromptSubmit entries: %d   Stop entries PRESERVED: %d" % (len(ups), n_stop))
print("  runs: %s" % hook_sh)
print("  backup: %s" % (settings + ".bak" if os.path.exists(settings + ".bak") else "(none -- file was new)"))
print("")
print("VERIFY IT FIRED: your very next prompt should be preceded by a POSTOFFICE line.")
print("If it is not, open /hooks once (reloads config) or restart -- the settings watcher only")
print("watches directories that already had a settings file when the session started.")
