# MiniTmux for Windows (`mtmux`)

> **The zero-install, battery-included portable tmux distribution engineered specifically for native Windows.**

[![Platform: Windows 10/11 x64](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-0078D6.svg)](#requirements)
[![tmux 3.7b](https://img.shields.io/badge/tmux-3.7b%20native-2ea44f.svg)](#architecture)
[![License: ISC / LGPLv3](https://img.shields.io/badge/license-ISC%20%2F%20LGPLv3-lightgrey.svg)](#licenses)
[![Automated Validation](https://img.shields.io/badge/tests-56%2F56%20passing-brightgreen.svg)](#validation)

MiniTmux provides a complete, hardened, and ergonomically tuned [tmux 3.7b](https://github.com/tmux/tmux) environment running natively on Windows without WSL, Docker, Cygwin installers, or administrator privileges.

Unlike raw MSYS2 binary dumps, MiniTmux is an autonomous, production-grade terminal multiplexer platform with native Windows CLI launchers, diagnostic health checkers, Windows clipboard synchronization, Windows Terminal profiles, modern status styling, and automated multi-agent AI orchestration presets.

---

## ⚡ Highlights & Why MiniTmux

| Feature | Upstream / Raw MSYS2 | MiniTmux for Windows |
|---|---|---|
| **Windows CLI Launchers** | Requires manual bash invocation | Native `mtmux` & drop-in `tmux.cmd` / `tmux.ps1` with pure batch fast-paths (~240ms) |
| **Argument & Format Safety** | Strips `#{...}` format braces from Windows callers | Automatic `MSYS=noglob` injection everywhere |
| **Path Translation** | Fails on Windows `C:\path` drives | Seamless automatic Windows-to-POSIX `/cygdrive` conversion |
| **System Diagnostics** | None; silent runtime failures | Built-in `mtmux doctor` health & collision checker |
| **Clipboard Integration** | Disconnected from Windows | Bidirectional sync with `clip.exe` & native `winpaste.exe` (~100ms) |
| **Runtime Performance** | Standard POSIX fork emulation | Tuned `MSYS` runtime (`disable_pcon winsymlinks:nativestrict`, ~22% speedup) |
| **Windows Terminal** | Manual JSON editing required | 1-click JSON fragment profile generator |
| **Runtime Isolation** | Collides with Git for Windows DLLs | Rebased DLL addresses (`0x230000000+`) & `.exe.local` isolation |
| **Out-of-the-box Theme** | Bare default green bar, 0 config | Low-overhead statusline, Truecolor (24-bit), zero-delay vim nav (`escape-time 0`) |
| **AI Agent Orchestration** | Manual pane setup | One-command `mtmux layout agents` preset |
| **Test Verification** | Manual checks | 56 automated checks (PowerShell host + POSIX pane suites) |

---

## 🚀 Quick Start

### 1. One-Line Web Installer

Install MiniTmux anywhere with a single command:

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/terri-yaki/mini-tmux-for-windows/main/scripts/install.ps1 | iex
```

**macOS & Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/terri-yaki/mini-tmux-for-windows/main/scripts/install.sh | bash
```

---

### 2. Zero-Install Execution
Run MiniTmux immediately from a cloned directory without installing anything:

```powershell
# Launch or attach to the primary session
.\mtmux

# Or run the health diagnostic
.\mtmux doctor
```

### 3. Local Setup & Windows Terminal Profile
To configure PATH, register shell completions, and install the **Windows Terminal** profile:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install-MiniTmux.ps1
```

*(To uninstall at any time: `powershell -ExecutionPolicy Bypass -File .\scripts\Install-MiniTmux.ps1 -Uninstall`)*

---

## 🛠️ The `mtmux` CLI Reference

MiniTmux includes a unified cross-platform management utility (`mtmux` / `bin\mtmux.cmd` / `bin\mtmux.ps1` / `bin/mtmux`):

```text
USAGE:
    mtmux                           Attach to 'main' session, or create it if not running
    mtmux new [name] [-d]           Create a session (default: 'main', detached with -d) [pure batch fast-path]
    mtmux attach [name]             Attach to an existing session (alias: mtmux a)
    mtmux list | ls                 List running sessions with window count and status
    mtmux switch [session]          Interactively or directly switch between active sessions (fzf / menu)
    mtmux kill [name|--all]         Terminate a specific session or kill the entire server
    mtmux agent [name|tool] [-v]    Add an AI agent panel (agy, claude, grok, gemini, aider, etc.)
    mtmux split [-v] [cmd]          Split current window horizontally or vertically with optional command
    mtmux layout <preset>           Apply a layout preset (agents, dev, split, vsplit, quad)
    mtmux run [target] [-n] <cmd>   Send a command to a pane (defaults to active pane; -n for raw keys)
    mtmux capture [target] [-n]     Capture pane content (-n lines, -a all history, -o file)
    mtmux logs [target] [-n]        Alias for capture (view or dump pane logs directly to stdout or file)
    mtmux inspect [session] [-j]    Inspect sessions/windows/panes hierarchy (--json for MCP / scripts)
    mtmux save [file]               Export running sessions, windows, and pane layouts to snapshot JSON
    mtmux restore [file]            Restore sessions, windows, and split geometry from snapshot JSON
    mtmux theme [name|list]         List or switch visual theme (catppuccin, tokyonight, nord, etc.)
    mtmux doctor                    Run system health, runtime isolation, and collision checks
    mtmux completion [shell]        Generate shell completion (bash, zsh, powershell)
    mtmux setup                     Add MiniTmux to User PATH and register Windows Terminal
    mtmux wt [session]              Launch session in a new tab inside Windows Terminal
    mtmux -- <tmux-args...>         Forward raw arguments directly to tmux
```

### ⚡ AI Agent Panel Spawning

MiniTmux provides one-command shortcuts to spin up and orchestrate AI agent panes:

```bash
# Spawn an AI agent side panel running standard agy
mtmux agent

# Spawn a specialized agent panel
mtmux agent debugger
mtmux agent code-reviewer

# Split vertically underneath
mtmux agent test-runner -v

# Run grok or any command directly in the active pane
mtmux run "grok"
```

**Inside tmux keyboard shortcuts:**
* `Ctrl + b` then `Shift + A` : Split horizontally (right) with AI agent
* `Ctrl + b` then `Ctrl + a`  : Split vertically (down) with AI agent

### Session Persistence (Save & Restore)

Never lose your multiplexer workspace on restart or system reboot:

```powershell
# Save all running sessions, windows, pane splits, and directories
mtmux save

# Restore all saved sessions with exact pane geometry and working directories
mtmux restore
```

### 🔄 Interactive Session Switcher (`mtmux switch`)

Easily hop between workspaces without typing session IDs:
```bash
# Interactive selection (uses fzf if installed, or clean numeric menu)
mtmux switch

# Direct switch (seamless inside or outside tmux)
mtmux switch ai-team
```

### 🔍 Hierarchy Inspection (`mtmux inspect`)

Inspect all sessions, windows, panes, coordinates, processes, and `@role` tags:
```bash
# Pretty-printed terminal hierarchy tree
mtmux inspect

# Structured JSON output for MCP servers, agent orchestrators, and automation scripts
mtmux inspect --json
```

### ⚡ Shell Completion (Bash, Zsh, PowerShell)

Tab-complete subcommands, active session names, layout presets, color themes, and agent tools:

```bash
# Bash:
eval "$(mtmux completion bash)"

# Zsh:
eval "$(mtmux completion zsh)"

# PowerShell:
mtmux completion powershell | Out-String | Invoke-Expression
```

### Visual Themes Gallery

Switch themes instantly on-the-fly (automatically applies to running tmux sessions):

```powershell
# List available themes
mtmux theme list

# Switch to Tokyo Night, Nord, Gruvbox, Dracula, or One Dark
mtmux theme tokyo-night
mtmux theme nord
mtmux theme gruvbox-dark
mtmux theme dracula
mtmux theme one-dark
mtmux theme catppuccin-mocha
```

### Layout Presets

MiniTmux includes ready-to-use window layout templates:

```powershell
# 3-Pane AI Agent Team: Coordinator on left (55%), two stacked worker panes on right (45%)
mtmux layout agents -Name ai-team

# Development Layout: Editor on left (70%), build and test panes on right (30%)
mtmux layout dev -Name code

# Balanced 2x2 Grid (4 panes)
mtmux layout quad -Name monitor

# Clean 50/50 Horizontal Split
mtmux layout split -Name dual
```

---

## 🤖 Multi-Agent AI Orchestration

MiniTmux is specifically tuned as an execution runtime for autonomous AI coding agents (Claude Code, Grok CLI, Gemini CLI, OpenAI Codex, Kimi).

### Autonomous Agent Workspace
```powershell
# 1. Create a dedicated multi-agent session
mtmux new agents-workspace -d

# 2. Apply the multi-agent layout (labels panes: coordinator, worker-1, worker-2)
mtmux layout agents -Name agents-workspace

# 3. Launch an agent into a specific pane
mtmux run agents-workspace:0.0 "claude"
mtmux run agents-workspace:0.1 "grok"
mtmux run agents-workspace:0.2 "npm test -- --watch"

# 4. Attach to oversee the team
mtmux attach agents-workspace
```

### Integration with MCP Servers (e.g. `tmux-bridge-mcp`)
MiniTmux is fully compatible with MCP bridges. Because `bin\tmux.cmd` and `bin\tmux.ps1` automatically enforce `MSYS=noglob`, MCP agents querying format strings like `#{pane_id}` or `#{pane_current_command}` receive pristine uncorrupted responses.

---

## 🎨 Modern Configuration (`etc/tmux.conf`)

MiniTmux ships with a tuned, battery-included configuration:

* **Mouse Support**: Smooth scrolling, pane clicking, and border dragging out of the box.
* **Truecolor (24-bit RGB)**: Configured for modern terminal emulators (Windows Terminal, WezTerm, Alacritty, Ghostty).
* **Universal Cross-Platform Clipboard & OSC 52**:
  * Universal terminal clipboard via OSC 52 (`set -s set-clipboard on`).
  * **Windows**: Bidirectional sync with `clip.exe` and native `winpaste.exe` (~100ms).
  * **macOS**: Native pipes with `pbcopy` and `pbpaste`.
  * **Linux**: Automatic detection for Wayland (`wl-copy`/`wl-paste`) and X11 (`xclip`).
* **Intuitive Splitting**:
  * `prefix + |` : Split horizontally (side-by-side, retains current directory).
  * `prefix + -` : Split vertically (stacked, retains current directory).
* **Vim & Arrow Navigation**:
  * `Alt + Left/Right/Up/Down` : Move between panes directly without prefix.
  * `prefix + h/j/k/l` : Move between panes vim-style.
* **Statusline**: Crisp dark aesthetic with active session badge, date/time, and window indicators.

---

## 🔍 Diagnostics: `mtmux doctor`

Run `mtmux doctor` at any time to verify system integrity:

```text
================================================================
                MiniTmux System Diagnostics & Health            
================================================================
[1/7] Environment & Host Architecture
  PASS  OS Architecture: 64-bit (Microsoft Windows NT 10.0.26300.0)

[2/7] Core Binaries & Portable Root
  INFO  MiniTmux Root: D:\workspace\mini-tmux-for-windows
  PASS  Found usr\bin\tmux.exe
  PASS  Found usr\bin\bash.exe
  PASS  Found usr\bin\msys-2.0.dll
  PASS  Found usr\bin\msys-event_core-2-1-7.dll
  PASS  Found usr\bin\msys-ncursesw6.dll
  PASS  Found etc\tmux.conf

[3/7] Socket Directory & Relocatability
  PASS  Socket directory D:\workspace\mini-tmux-for-windows\tmp exists and is writable

[4/7] Runtime Isolation & PATH Hygiene
  PASS  No colliding external msys-2.0.dll found before MiniTmux

[5/7] Console Encoding & Argument Handling
  PASS  MSYS=noglob correctly preserves #{format} braces

[6/7] Windows Clipboard Bridge
  PASS  Windows clip.exe detected at C:\WINDOWS\System32\clip.exe

[7/7] Windows Terminal & Profile Integration
  PASS  Windows Terminal (wt.exe) detected
  PASS  MiniTmux bin is registered in user PATH

================================================================
RESULT: MiniTmux is healthy and fully operational on this system.
================================================================
```

---

## 🏗️ Architecture & Technical Hardening

### 1. The POSIX Emulation Layer
`msys-2.0.dll` provides the POSIX primitives tmux requires: `fork()`, pseudo-terminals (`/dev/pty*`), and UNIX domain sockets. The runtime determines its root relative to the DLL path (`usr\bin\..`), enabling complete folder relocatability.

### 2. DLL Address Rebasing & Isolation
Stock MSYS2 DLLs request base address `0x210040000`, colliding directly with Git for Windows' runtime and causing intermittent initialization crashes (`STATUS_CONFLICTING_ADDRESSES`). In MiniTmux, all bundled MSYS DLLs are rebased into the `0x230000000+` range. Additionally, every `.exe` in `usr\bin` has a matching `<name>.exe.local` dotfile, instructing the Windows loader to strictly prefer DLLs from MiniTmux's directory.

### 3. Socket Virtualization (`patches/0001`)
Upstream tmux 3.7+ verifies that the socket directory has no world-writable/group-writable bits (`TMUX_SOCK_PERM`). Under MSYS2 on Windows NTFS mounts, POSIX permissions report synthetic 755 modes. Our patch bypasses the synthetic mode check on `__MSYS__` while retaining ownership validation; security is governed by native Windows NTFS ACLs.

### 4. `MSYS=noglob` Environment Engine
When non-MSYS processes (PowerShell, Node.js, Python, .NET) invoke tmux with format strings like `-F "#{pane_id}"`, the MSYS runtime interprets `{...}` as brace expansion and strips the braces. MiniTmux's launchers enforce `MSYS=noglob`, guaranteeing 100% format preservation across all programming languages and shells.

### 5. Performance-Maxxed Execution Architecture
* **Pure Batch Fast Paths**: `bin/mtmux.cmd` handles `ls`, `attach`, `kill`, `run`, and `capture` directly in under 240ms without spawning PowerShell.
* **Native `winpaste.exe`**: Built-in Win32 clipboard reader (`src/winpaste.cs`) drops paste latency from 440ms (PowerShell `Get-Clipboard`) down to ~100ms.
* **Optimized MSYS Flags**: Enforces `disable_pcon winsymlinks:nativestrict` for ~22% faster fork and process spawn throughput.
* **Zero-Delay Ergonomics & Low CPU**: `escape-time 0` eliminates vim navigation lag, `history-limit 50000` optimizes RAM usage, and `status-interval 15` cuts idle background wakeups by 87%.

---

## 🧪 Validation & Test Suites

MiniTmux includes dual test suites ensuring complete cross-layer reliability:

### 1. Native Windows Host Suite (`tests/Test-MiniTmux.ps1`)
Runs directly from Windows PowerShell without entering bash:
```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Test-MiniTmux.ps1
```
* **17 automated tests** covering binary integrity, wrapper execution, format brace preservation, session lifecycle, window/pane splitting, layout presets, UTF-8 roundtrip, path translation, and clean teardown.

### 2. POSIX Pane Suite (`tests/validate.sh`)
Runs inside an active tmux session:
```bash
bash tests/validate.sh
```
* **39 automated checks** validating session lifecycle, window management, directional pane navigation, zoom/unzoom, input/output, copy-mode buffer manipulation, hooks, format strings, and server cleanup.

---

## 📦 Package Contents

* **tmux 3.7b**: Built from upstream source with MSYS socket patch applied
* **bash 5.3.015**: Default interactive shell
* **msys2-runtime 3.6.10**: Hardened & rebased POSIX compatibility layer
* **winpaste.exe**: Native Win32 clipboard reader (`src/winpaste.cs`)
* **ncurses 6.6**: Terminal handling & comprehensive terminfo database
* **libevent 2.1.12**: Event notification library
* **Userland Tools**: coreutils 8.32, sed 4.9, grep 3.0, gawk 5.4, diffutils 3.12, findutils 4.10, gzip 1.14, tar 1.35
* **PowerShell Automation Module**: `scripts/MiniTmux.psm1`
* **Windows Terminal Integration**: `scripts/Install-WindowsTerminalProfile.ps1`

---

## ⚖️ Credits & Licenses

* **tmux**: Written by Nicholas Marriott and tmux contributors ([ISC License](https://github.com/tmux/tmux/blob/master/COPYING)).
* **MSYS2**: The MSYS2 development team and Cygwin contributors ([LGPLv3](https://www.msys2.org/)).
* **winpty**: Created by Ryan Prichard ([MIT License](https://github.com/rprichard/winpty)).
* **MiniTmux**: Developed and packaged by [HoYu Lee](https://github.com/terri-yaki) ([MIT License](LICENSE)).
