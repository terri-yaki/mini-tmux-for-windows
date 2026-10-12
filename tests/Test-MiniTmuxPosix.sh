#!/usr/bin/env bash
# ==============================================================================
# MiniTmux POSIX Automated Test Suite (tests/Test-MiniTmuxPosix.sh)
# Verifies bin/mtmux functionality on macOS and Linux
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MTMUX="$REPO_ROOT/bin/mtmux"

TOTAL=0
PASSED=0
FAILED=0

assert_eq() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$expected" = "$actual" ]; then
        PASSED=$((PASSED + 1))
        echo -e "\033[32m  PASS  $name\033[0m"
    else
        FAILED=$((FAILED + 1))
        echo -e "\033[31m  FAIL  $name (expected '$expected', got '$actual')\033[0m"
    fi
}

assert_contains() {
    local name="$1"
    local pattern="$2"
    local text="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$text" | grep -q "$pattern"; then
        PASSED=$((PASSED + 1))
        echo -e "\033[32m  PASS  $name\033[0m"
    else
        FAILED=$((FAILED + 1))
        echo -e "\033[31m  FAIL  $name (pattern '$pattern' not found in output)\033[0m"
    fi
}

assert_zero() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    shift
    if "$@" >/dev/null 2>&1; then
        PASSED=$((PASSED + 1))
        echo -e "\033[32m  PASS  $name\033[0m"
    else
        FAILED=$((FAILED + 1))
        echo -e "\033[31m  FAIL  $name (command exited non-zero)\033[0m"
    fi
}

echo -e "\033[36mRunning MiniTmux POSIX Automated Verification Suite...\033[0m"

# 1. Doctor check
DOC_OUT="$("$MTMUX" doctor)"
assert_contains "mtmux doctor reports binary" "tmux binary" "$DOC_OUT"
assert_contains "mtmux doctor reports ready" "MiniTmux is ready" "$DOC_OUT"

# 2. Theme listing
THEMES_OUT="$("$MTMUX" theme list)"
assert_contains "theme list contains tokyo-night" "tokyo-night" "$THEMES_OUT"
assert_contains "theme list contains catppuccin-mocha" "catppuccin-mocha" "$THEMES_OUT"

# 3. Theme switching
assert_zero "theme switch to nord" "$MTMUX" theme nord
assert_contains "active theme file updated" "Nord theme" "$(cat "$REPO_ROOT/etc/themes/current.conf")"

# 4. Session lifecycle
SESS="ci-posix-$$"
assert_zero "create detached session" "$MTMUX" new -d "$SESS"

LS_OUT="$("$MTMUX" ls)"
assert_contains "session listed in ls" "$SESS" "$LS_OUT"

# 4b. Dynamic agent panel & split
assert_zero "add split pane" "$MTMUX" split -h -t "$SESS" "echo SPLIT_TEST_OK"
PANE_SPLIT_COUNT="$(tmux list-panes -t "$SESS" | wc -l | tr -d ' ')"
assert_eq "split added second pane" "2" "$PANE_SPLIT_COUNT"

assert_zero "add agent panel" "$MTMUX" agent test-runner -t "$SESS"
PANE_AGENT_COUNT="$(tmux list-panes -t "$SESS" | wc -l | tr -d ' ')"
assert_eq "agent added third pane" "3" "$PANE_AGENT_COUNT"

# 5. Agent layout preset
AGENT_SESS="ci-agents-$$"
assert_zero "create agents layout" "$MTMUX" layout agents -d -Name "$AGENT_SESS"

PANE_COUNT="$(tmux list-panes -t "$AGENT_SESS" | wc -l | tr -d ' ')"
assert_eq "agents layout has 3 panes" "3" "$PANE_COUNT"

ROLE_0="$(tmux display-message -p -t "${AGENT_SESS}.0" '#{@role}' 2>/dev/null || tmux display-message -p -t "${AGENT_SESS}:0.0" '#{@role}')"
ROLE_1="$(tmux display-message -p -t "${AGENT_SESS}.1" '#{@role}' 2>/dev/null || tmux display-message -p -t "${AGENT_SESS}:0.1" '#{@role}')"
ROLE_2="$(tmux display-message -p -t "${AGENT_SESS}.2" '#{@role}' 2>/dev/null || tmux display-message -p -t "${AGENT_SESS}:0.2" '#{@role}')"
assert_eq "pane 0 role is coordinator" "coordinator" "$ROLE_0"
assert_eq "pane 1 role is worker-1" "worker-1" "$ROLE_1"
assert_eq "pane 2 role is worker-2" "worker-2" "$ROLE_2"

# 6. Run & capture
assert_zero "run command in coordinator pane" "$MTMUX" run "${AGENT_SESS}" "echo POSIX_VERIFY_12345"
sleep 0.5
CAPTURED="$("$MTMUX" capture "${AGENT_SESS}:0.0")"
assert_contains "capture pane verified command output" "POSIX_VERIFY_12345" "$CAPTURED"

# 6b. Run without target argument (smart active pane detection)
assert_zero "run command without target argument" "$MTMUX" run "echo NO_TARGET_AUTO_PANE"
sleep 0.5
CAPTURED_AUTO="$("$MTMUX" capture)"
assert_contains "smart run targeted active pane" "NO_TARGET_AUTO_PANE" "$CAPTURED_AUTO"

# 7. Teardown
assert_zero "kill session $SESS" "$MTMUX" kill "$SESS"
assert_zero "kill session $AGENT_SESS" "$MTMUX" kill "$AGENT_SESS"

# Restore default theme
"$MTMUX" theme catppuccin-mocha >/dev/null 2>&1 || true

echo "------------------------------------------------------------"
echo -e "\033[1mResults: $PASSED / $TOTAL passed ($FAILED failed)\033[0m"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
