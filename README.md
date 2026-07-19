# mini-tmux-for-windows

tmux 3.6a running natively on Windows. No WSL, no installer, no admin rights.

This is a repackaging of unmodified binaries from the MSYS2 package
repositories (https://repo.msys2.org/msys/x86_64/) plus the minimal set of
runtime libraries they link against. Nothing was compiled or patched for
this repo; the only hand-written file is `etc/tmux.conf`.

tmux itself is written by **Nicholas Marriott** — upstream lives at
https://github.com/tmux/tmux. This repo only packages his work for Windows;
all credit for tmux goes to him and the tmux contributors.

## How it works

`msys-2.0.dll` is the MSYS2 runtime (a Cygwin fork). It gives Windows
processes the POSIX layer tmux needs: `fork()`, pseudo-terminals, and unix
domain sockets. The runtime locates its install root from its own DLL path,
which is why the directory layout is fixed and the folder is relocatable:

```
<root>
├── usr\bin\        tmux.exe, bash.exe, sh.exe, winpty, runtime DLLs
├── usr\share\      terminfo
├── etc\tmux.conf   default-shell = /usr/bin/bash
└── tmp\            tmux server socket: /tmp/tmux-<uid>/default
```

Move the folder wherever you want, but keep the structure. `tmp\` must
exist — tmux creates the `tmux-<uid>` subdirectory itself but not the
parent, and without it `new-session` dies with "no suitable socket path".

## Install

```
git clone https://github.com/terri-yaki/mini-tmux-for-windows.git
```

Put the cloned folder anywhere — the layout is self-contained, no fixed
location required. Then add its `usr\bin` directory to the user PATH and
open a new terminal (PATH changes don't reach already-running processes).
Verify with `tmux -V`.

## User guide

Everything below is plain upstream tmux — commands run in any shell once
`usr\bin` is on PATH. `tmux` is the client; the first command that needs a
server starts one (socket in `tmp\tmux-<uid>\default`).

Most commands have short aliases; the ones used here are spelled out.

### Sessions

```
tmux new-session -s work                 start a session named "work", attached
tmux new-session -d -s work              same, but detached (background)
tmux new-session -d -s work -x 220 -y 50 detached with an initial size
tmux attach-session -t work              attach to it later
tmux list-sessions                       what's running
tmux rename-session -t work newname      rename
tmux kill-session -t work                kill one session (its server dies if it was the last)
tmux kill-server                         kill the server and every session
```

Inside a session you detach with `C-b d` — everything keeps running.

### Panes

```
tmux split-window -h                     split left/right
tmux split-window -v                     split top/bottom
tmux split-window -h -t work:0.0         split a specific pane
tmux split-window -h -p 30               give the new pane 30% of the space
tmux select-pane -t work:0.1             focus a pane by target
tmux resize-pane -t work:0.1 -x 100      set exact width (cells)
tmux kill-pane -t work:0.1               close a pane
tmux list-panes -a                       every pane in every session
```

Targets: `%3` (pane id), `work:0.1` (session:window.pane), or a label you
set yourself (see below).

### Windows (tabs inside a session)

```
tmux new-window -t work                  add a window
tmux new-window -n logs -t work          add one named "logs"
tmux select-window -t work:1             switch
tmux rename-window -t work:0 editor      rename
tmux kill-window -t work:1               close
```

### Sending input and reading output (scripting)

This is what tmux-bridge-mcp uses, but it works fine by hand too.

```
tmux send-keys -t work:0.0 'git status' Enter    type into a pane and hit Enter
tmux send-keys -t work:0.0 C-c                   send Ctrl-C
tmux send-keys -t work:0.0 -l 'literal'          type literally, no key names
tmux capture-pane -t work:0.0 -p                 print the visible pane to stdout
tmux capture-pane -t work:0.0 -p -S -100         last 100 lines incl. scrollback
tmux capture-pane -t work:0.0 -p -J              -J joins wrapped lines
tmux display-message -p -t work:0.0 '#{pane_current_command}'
```

### Pane labels

User options on panes — handy for addressing panes by role instead of id:

```
tmux set-option -p -t work:0.0 @name kimi
tmux list-panes -a -F '#{pane_id} #{@name}'
```

### Options

`set-option` (alias `set`) changes server/session/window/pane behavior:

```
tmux set -g history-limit 50000          scrollback lines (server-wide)
tmux set -g default-shell /usr/bin/bash  pane shell (already in etc/tmux.conf)
tmux set -g mouse on                     mouse select/resize panes
tmux set -g status off                   hide the status bar
tmux set -g escape-time 10               ms tmux waits after Escape
tmux show-options -g                     dump current server options
tmux show-window-options -g              dump window options
```

Session config file is `etc\tmux.conf` (read at server start); after
editing it, `tmux kill-server` and start fresh, or `tmux source-file`
the path inside a session.

### winpty

Prefix any Windows console program with `winpty` to give it a real
console inside the pane:

```
winpty cmd
winpty powershell
winpty python
winpty node app.js
```

### Key bindings (defaults)

Prefix is `C-b` (Ctrl-b). After the prefix, tmux listens for one key.

| Keys | Action |
|------|--------|
| `C-b %` / `C-b "` | split pane vertical / horizontal |
| `C-b ←→↑↓` | move between panes |
| `C-b z` | zoom pane fullscreen / back |
| `C-b x` | kill current pane (asks) |
| `C-b c` | new window |
| `C-b n` / `C-b p` | next / previous window |
| `C-b 0..9` | jump to window N |
| `C-b ,` | rename window |
| `C-b &` | kill window (asks) |
| `C-b d` | detach |
| `C-b [` | copy mode (scrollback; `q` exits) |
| `C-b ?` | list all key bindings |
| `C-b :` | command prompt (type any tmux command) |

## Command reference

`tmux` itself:

| Flag | Meaning |
|------|---------|
| `-V` | print version |
| `-S path` | use a specific server socket path |
| `-L name` | use a named server socket (separate servers) |
| `-f file` | use a different config file |
| `-u` / `-U` | force UTF-8 |
| `-v`, `-vv` | verbose server logging (writes `tmux-*.log` in cwd) |
| `-CC` | control mode (for terminal integration) |

Commands you'll actually use (full grammar: `tmux list-commands`, or the
upstream man page at https://man.openbsd.org/tmux):

| Command | Common flags |
|---------|--------------|
| `new-session` | `-d` detached, `-s name`, `-x cols`, `-y rows`, `-c start-dir`, `command` |
| `attach-session` | `-t target`, `-d` detach others, `-r` read-only |
| `list-sessions` | `-F format` |
| `kill-session` | `-t target`, `-a` all-but |
| `rename-session` | `-t target newname` |
| `new-window` | `-t target`, `-n name`, `-c dir`, `-d` stay |
| `select-window` | `-t target`, `-n`/`-p` next/prev |
| `kill-window` | `-t target`, `-a` all-but |
| `rename-window` | `-t target newname` |
| `split-window` | `-h`/`-v`, `-t pane`, `-p pct` / `-l size`, `-c dir`, `command` |
| `select-pane` | `-t pane`, `-L/-R/-U/-D` by direction, `-l` last |
| `kill-pane` | `-t pane`, `-a` all-but |
| `resize-pane` | `-t pane`, `-x w`, `-y h`, `-L/-R/-U/-D n` |
| `swap-pane` | `-s src`, `-d dst`, `-U`/`-D` |
| `list-panes` | `-a` all sessions, `-s` session, `-t window`, `-F format` |
| `send-keys` | `-t pane`, `-l` literal, `-X` copy-mode key, key names (`Enter`, `C-c`, `Escape`, `BSpace`, arrows, `F1`..) |
| `capture-pane` | `-t pane`, `-p` to stdout, `-S n`/`-E n` start/end line, `-J` join, `-e` keep escapes |
| `pipe-pane` | `-t pane`, `-o`, shell command to tee output |
| `set-option` | `-g` global, `-s` server, `-w` window, `-p` pane, `-u` unset, `-a` append |
| `show-options` | `-g`, `-s`, `-w`, `-p`, `-v` value only |
| `display-message` | `-p` print, `-t target`, `-F format`, `message`/`format` |
| `source-file` | config path |
| `list-commands` | every command and its syntax |
| `list-keys` | every key binding |
| `kill-server` | no flags |

Format strings (`-F`, used by `list-panes`, `display-message`, etc.) expand
`#{...}` variables — `pane_id`, `session_name`, `window_index`,
`pane_current_command`, `pane_current_path`, user options like `@name`.
On Windows, remember `MSYS=noglob` when these come from a non-MSYS parent
(see above).

## MSYS=noglob

When tmux is spawned by a non-MSYS parent (Node, Python, .NET — anything
not linked against `msys-2.0.dll`), the runtime performs POSIX argument
globbing on the incoming Windows command line. That includes brace
expansion, so `-F '#{pane_id}'` arrives at tmux as `#pane_id` and the
format string is dead. Arguments containing spaces get quoted by the parent
and survive untouched; bare ones don't.

Set `MSYS=noglob` in the parent process environment to disable this. If a
`-F` format ever comes back echoed literally, this is why. (Hit firsthand
via tmux-bridge-mcp, which feeds brace-heavy `-F` strings through Node's
`child_process`.)

## Don't mix runtimes

Git for Windows ships its own fork of the msys runtime, ABI-incompatible
with upstream MSYS2's. A pane (which already has MSYS2's runtime mapped)
cannot exec Git Bash's `bash.exe` — the child keeps the loaded runtime and
the mismatched binary dies on startup. Use the bundled bash inside panes.
Calling this tmux *from* Git Bash is fine; that's a separate process.

## Package manifest

All binaries unmodified from https://repo.msys2.org/msys/x86_64/:

- tmux-3.6.a-1
- bash-5.3.015-1
- msys2-runtime-3.6.9-2
- libevent-2.1.12-4
- ncurses-6.6-2 (libs + terminfo)
- libreadline-8.3.003-1
- libintl-0.22.5-1
- libiconv-1.19-1
- winpty-0.4.3-3

winpty is by **Ryan Prichard**: https://github.com/rprichard/winpty
Runtime and packaging infrastructure: the MSYS2 project,
https://github.com/msys2

## Uninstall

Delete the folder, remove it from PATH. No registry entries, no services.

## Licenses

tmux is ISC, bash is GPLv3, winpty is MIT, the MSYS2 runtime is LGPLv3
(Cygwin). All binaries redistributed unmodified; see the respective
projects for license texts.
