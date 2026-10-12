# Bash completion for mtmux
# Source this file or place it in /etc/bash_completion.d/ or ~/.local/share/bash-completion/completions/mtmux

_mtmux_completions() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="new attach a list ls kill agent split layout run capture logs switch inspect save restore theme themes doctor completion help"
    local layouts="agents dev split vsplit quad"

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
        return 0
    fi

    local subcmd="${COMP_WORDS[1]}"
    case "$subcmd" in
        attach|a|kill|switch|inspect|run|capture|logs)
            local sessions
            sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
            COMPREPLY=( $(compgen -W "$sessions" -- "$cur") )
            ;;
        layout)
            COMPREPLY=( $(compgen -W "$layouts" -- "$cur") )
            ;;
        theme)
            local themes="catppuccin-mocha tokyo-night nord gruvbox-dark dracula one-dark list"
            COMPREPLY=( $(compgen -W "$themes" -- "$cur") )
            ;;
        agent)
            local agent_tools="agy claude grok gemini aider -v -h -t"
            COMPREPLY=( $(compgen -W "$agent_tools" -- "$cur") )
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh powershell" -- "$cur") )
            ;;
    esac
}

complete -F _mtmux_completions mtmux
