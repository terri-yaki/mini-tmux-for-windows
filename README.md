# tmux for Windows

Portable [tmux](https://github.com/tmux/tmux) 3.6a for **native Windows** — no WSL, no admin rights, no installer. A minimal self-contained [MSYS2](https://www.msys2.org/) runtime with just enough to run tmux, bash, and winpty.

```
C:\> tmux new -s main
```

## What's inside

| Component | Version | Purpose |
|-----------|---------|---------|
| tmux | 3.6a | Terminal multiplexer |
| bash | 5.3 | Default pane shell (`/bin/sh` included) |
| winpty | 0.4.3 | Run interactive **Windows** CLIs (cmd, node-based tools, etc.) inside panes |
| MSYS2 runtime + libs | 3.6.9 | `msys-2.0.dll`, libevent, ncurses, readline, intl, iconv |
| terminfo | 6.6 | Terminal definitions for ncurses apps |
| `etc/tmux.conf` | — | Sets bash as the default shell |

Everything lives in one folder. Binaries are unmodified packages from the [MSYS2 package repos](https://repo.msys2.org/msys/x86_64/).

## Install

```bash
git clone https://github.com/terri-yaki/tmux-for-windows.git C:\tools\msys2-mini
```

Add `C:\tools\msys2-mini\usr\bin` to your `PATH` (User scope is enough). Then open a **new** terminal so the PATH takes effect.

> The folder layout matters: the MSYS2 runtime locates its root from the DLL path (`<root>\usr\bin\msys-2.0.dll`), and `/tmp` (needed for the tmux socket) maps to `<root>\tmp`. Keep the structure as-is.

## Usage

```bash
tmux new-session -s main     # start a session
tmux split-window -h         # split panes
tmux attach -t main          # reattach
```

Run interactive Windows-native programs inside panes via `winpty` — without it, Windows console apps (Node.js CLIs, Python, cmd, PowerShell) see a pipe instead of a console and their TTY UIs break:

```bash
winpty powershell
winpty python
```

## Note for developers: `MSYS=noglob`

If you spawn `tmux` from a **non-MSYS parent process** (Node.js, Python, .NET), the MSYS2 runtime glob-expands unquoted arguments — and strips `{}` braces from tmux `-F` format strings like `#{pane_id}`. Set this in the parent process environment to disable it:

```
MSYS=noglob
```

(This is required, for example, when running [tmux-bridge-mcp](https://github.com/howardpen9/tmux-bridge-mcp) on Windows.)

## Uninstall

Delete the folder and remove it from `PATH`. Nothing else is touched — no registry, no services, no admin ever needed.

## Licenses

All binaries are redistributed unmodified from the MSYS2 project. tmux is ISC-licensed, bash is GPLv3, winpty is MIT, the MSYS2 runtime is Cygwin (LGPLv3). See the respective projects for details.
