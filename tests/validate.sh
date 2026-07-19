#!/usr/bin/bash
# Validation suite for mini-tmux-for-windows. Expects a running server on the "validate" socket with session "main",
# started with a Git-free PATH so panes load the bundled runtime:
#   PATH="/d/workspace/mini-tmux-for-windows/usr/bin:/c/WINDOWS/system32:/c/WINDOWS" #   tmux -L validate new-session -d -s main -x 220 -y 50
# then, inside that session's pane:
#   bash /tmp/validate.sh
export PATH="/cygdrive/d/workspace/mini-tmux-for-windows/usr/bin:$PATH"
TMUX="tmux -L validate"
PASS=0; FAIL=0

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS  $1";
  else FAIL=$((FAIL+1)); echo "FAIL  $1  (want [$2] got [$3])"; fi
}
rc_ok() { local _name="$1"; shift # rc_ok <name> <cmd...>
  if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS  $_name";
  else FAIL=$((FAIL+1)); echo "FAIL  $_name"; fi
}

# ── A. binary + session lifecycle ─────────────────────────────
check "session listed" "main" "$($TMUX list-sessions -F '#{session_name}')"
rc_ok "rename-session" $TMUX rename-session work
check "rename took effect" "work" "$($TMUX list-sessions -F '#{session_name}')"

# ── B. windows ────────────────────────────────────────────────
rc_ok "new-window" $TMUX new-window -t work -n logs
check "window count" "2" "$($TMUX list-windows -t work -F x | wc -l | tr -d ' ')"
check "window name" "logs" "$($TMUX list-windows -t work -F '#{window_name}' | tail -1)"
rc_ok "select-window" $TMUX select-window -t work:0
rc_ok "kill-window" $TMUX kill-window -t work:1

# ── C. panes ──────────────────────────────────────────────────
rc_ok "split-window -h" $TMUX split-window -h -t work:0
rc_ok "split-window -v" $TMUX split-window -v -t work:0
check "pane count" "3" "$($TMUX list-panes -t work:0 -F x | wc -l | tr -d ' ')"
rc_ok "select-pane" $TMUX select-pane -t work:0.0
$TMUX resize-pane -t work:0.0 -x 60
check "resize-pane" "60" "$($TMUX list-panes -t work:0.0 -F '#{pane_width}' | head -1)"
rc_ok "swap-pane" $TMUX swap-pane -s work:0.0 -t work:0.1
rc_ok "zoom (resize -Z)" $TMUX resize-pane -Z -t work:0.1
rc_ok "unzoom" $TMUX resize-pane -Z -t work:0.1

# ── D. input / output ─────────────────────────────────────────
$TMUX send-keys -t work:0.0 'echo MARK_$((111+222))' Enter; sleep 1.2
check "send-keys + capture" "MARK_333" "$($TMUX capture-pane -t work:0.0 -p | grep -o MARK_333 | head -1)"
$TMUX send-keys -t work:0.0 -l 'echo LIT_$((1+1))'; $TMUX send-keys -t work:0.0 Enter; sleep 0.7
check "send-keys -l literal" 'LIT_$((1+1))' "$($TMUX capture-pane -t work:0.0 -p | grep -o 'LIT_\$((1+1))' | head -1)"
$TMUX send-keys -t work:0.0 'sleep 60' Enter; sleep 0.4
$TMUX send-keys -t work:0.0 C-c; sleep 0.7
$TMUX send-keys -t work:0.0 'echo AFTER_INTR' Enter; sleep 0.7
check "C-c interrupts sleep" "AFTER_INTR" "$($TMUX capture-pane -t work:0.0 -p | grep -o AFTER_INTR | head -1)"
$TMUX send-keys -t work:0.0 'seq 1 40' Enter; sleep 0.8
check "scrollback capture -S" "1" "$($TMUX capture-pane -t work:0.0 -p -S -45 | grep -c '^5$')"
rc_ok "capture -J join" $TMUX capture-pane -t work:0.0 -p -J
$TMUX send-keys -t work:0.0 'echo UTF8_OK_中文_✓' Enter; sleep 0.7
check "utf-8 roundtrip" "UTF8_OK_中文_✓" "$($TMUX capture-pane -t work:0.0 -p | grep -o 'UTF8_OK_中文_✓' | head -1)"

# ── E. copy mode + buffers ────────────────────────────────────
$TMUX copy-mode -t work:0.0; sleep 0.3
check "copy-mode entered" "1" "$($TMUX display-message -p -t work:0.0 '#{pane_in_mode}')"
rc_ok "copy-mode search-backward" $TMUX send-keys -t work:0.0 -X search-backward "MARK_333"
$TMUX send-keys -t work:0.0 -X cancel
rc_ok "set-buffer" $TMUX set-buffer -b clip "buffer-content-42"
check "show-buffer" "buffer-content-42" "$($TMUX show-buffer -b clip)"
$TMUX select-pane -t work:0.0
$TMUX send-keys -t work:0.0 -l 'echo -n PFX'
$TMUX paste-buffer -b clip -t work:0.0; $TMUX send-keys -t work:0.0 Enter; sleep 0.7
check "paste-buffer" "PFXbuffer-content-42" "$($TMUX capture-pane -t work:0.0 -p | grep -o 'PFXbuffer-content-42' | head -1)"

# ── F. hooks / formats / options ──────────────────────────────
$TMUX set-hook -g session-renamed 'set-option -g @hookfired yes'
$TMUX rename-session work2; sleep 0.5
check "session-renamed hook fired" "yes" "$($TMUX show-options -g -v @hookfired)"
$TMUX rename-session work
check "format expansion" "work:0.0" "$($TMUX display-message -p -t work:0.0 '#{session_name}:#{window_index}.#{pane_index}')"
$TMUX set-option -g status off
check "set status off" "off" "$($TMUX show-options -g -v status)"
$TMUX set-option -g status on
$TMUX set-option -g mouse on
check "set mouse on" "on" "$($TMUX show-options -g -v mouse)"
$TMUX set-option -p -t work:0.0 @name kimi
check "pane label @name" "kimi" "$($TMUX list-panes -t work:0.0 -F '#{@name}' | grep -m1 kimi)"
rc_ok "source-file tmux.conf" $TMUX source-file /cygdrive/d/workspace/mini-tmux-for-windows/etc/tmux.conf

# ── G. command prompt + multi-session ─────────────────────────
$TMUX send-keys -t work:0.0 C-b :; sleep 0.4
$TMUX send-keys -t work:0.0 -l 'display-message -p PROMPT_OK'; $TMUX send-keys -t work:0.0 Enter; sleep 0.7
check "C-b : prompt" "PROMPT_OK" "$($TMUX capture-pane -t work:0.0 -p | grep -o PROMPT_OK | head -1)"
rc_ok "second session" $TMUX new-session -d -s second
check "two sessions" "2" "$($TMUX list-sessions -F x | wc -l | tr -d ' ')"
$TMUX kill-session -t second
rc_ok "has-session (exists)" $TMUX has-session -t work
if $TMUX has-session -t nosuch 2>/dev/null; then FAIL=$((FAIL+1)); echo "FAIL  has-session negative"; else PASS=$((PASS+1)); echo "PASS  has-session negative"; fi

# ── H. server teardown ────────────────────────────────────────
rc_ok "kill-server" $TMUX kill-server

echo "----------------------------------------"
echo "RESULT: $PASS passed, $FAIL failed"
