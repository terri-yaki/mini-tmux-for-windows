# PowerShell completion for mtmux
# Add to $PROFILE: . (mtmux completion powershell) or source directly

if (Get-Command Register-ArgumentCompleter -ErrorAction SilentlyContinue) {
    $scriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        $subcommands = @('new', 'attach', 'a', 'list', 'ls', 'kill', 'agent', 'split', 'layout', 'run', 'capture', 'logs', 'switch', 'inspect', 'save', 'restore', 'theme', 'themes', 'doctor', 'setup', 'wt', 'completion', 'help')
        $layouts = @('dev', 'split', 'vsplit', 'quad', 'agents')
        $elements = $commandAst.Elements
        if ($elements.Count -le 2) {
            return ($subcommands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "MiniTmux subcommand: $_")
            })
        }
        $subcmd = $elements[1].Extent.Text
        if ($subcmd -in @('attach', 'a', 'kill', 'switch', 'inspect', 'run', 'capture', 'logs', 'wt')) {
            $sessions = tmux list-sessions -F "#{session_name}" 2>$null
            if ($sessions) {
                return ($sessions | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Session: $_")
                })
            }
        }
        if ($subcmd -eq 'layout') {
            return ($layouts | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Layout preset: $_")
            })
        }
        if ($subcmd -eq 'theme') {
            $themes = @('catppuccin-mocha', 'tokyo-night', 'nord', 'gruvbox-dark', 'dracula', 'one-dark', 'list')
            return ($themes | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Theme: $_")
            })
        }
        if ($subcmd -eq 'agent') {
            $agents = @('agy', 'claude', 'grok', 'gemini', 'aider', '-v', '-h', '-t')
            return ($agents | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Agent / tool: $_")
            })
        }
        if ($subcmd -eq 'completion') {
            return (@('powershell', 'bash', 'zsh') | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Shell: $_")
            })
        }
    }
    Register-ArgumentCompleter -Native -CommandName 'mtmux' -ScriptBlock $scriptBlock
    Register-ArgumentCompleter -Native -CommandName 'mtmux.cmd' -ScriptBlock $scriptBlock
    Register-ArgumentCompleter -Native -CommandName 'mtmux.ps1' -ScriptBlock $scriptBlock
}
