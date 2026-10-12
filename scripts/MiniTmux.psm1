<#
.SYNOPSIS
    MiniTmux PowerShell Module
.DESCRIPTION
    Provides native PowerShell cmdlets to interact with and automate MiniTmux sessions,
    windows, panes, snapshots, themes, and multi-agent workflows.
#>

$Script:MiniTmuxRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Script:TmuxExe = Join-Path $Script:MiniTmuxRoot 'usr\bin\tmux.exe'
$Script:MtmuxPs1 = Join-Path $Script:MiniTmuxRoot 'bin\mtmux.ps1'

# Ensure noglob and high-performance runtime flags are set
$env:MSYS = 'noglob disable_pcon winsymlinks:nativestrict'

function Get-MiniTmuxSession {
    [CmdletBinding()]
    param()

    $raw = & $Script:TmuxExe list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}|#{session_created_string}" 2>$null
    if (-not $raw) { return @() }

    $result = @()
    foreach ($line in $raw) {
        $p = $line -split '\|'
        $result += [PSCustomObject]@{
            Name     = $p[0]
            Windows  = [int]$p[1]
            Attached = ($p[2] -eq "1")
            Created  = if ($p.Count -gt 3) { $p[3] } else { "" }
        }
    }
    return $result
}

function New-MiniTmuxSession {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = "main",

        [switch]$Detached,

        [string]$Directory,

        [string]$Layout
    )

    $argsList = @("new-session", "-s", $Name)
    if ($Detached) { $argsList += "-d" }
    if ($Directory) {
        $full = [System.IO.Path]::GetFullPath($Directory)
        if ($full -match '^([a-zA-Z]):\\(.*)$') {
            $posix = "/cygdrive/$($Matches[1].ToLower())/$($Matches[2].Replace('\', '/'))"
            $argsList += @("-c", $posix)
        }
    }

    & $Script:TmuxExe @argsList

    if ($Layout) {
        & $Script:MtmuxPs1 layout $Layout -Name $Name
    }
}

function Remove-MiniTmuxSession {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$All
    )

    if ($All) {
        & $Script:TmuxExe kill-server
    } elseif ($Name) {
        & $Script:TmuxExe kill-session -t $Name
    } else {
        & $Script:TmuxExe kill-session -t "main"
    }
}

function Send-MiniTmuxKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Text,

        [switch]$NoEnter
    )

    & $Script:TmuxExe send-keys -t $Target -l $Text
    if (-not $NoEnter) {
        & $Script:TmuxExe send-keys -t $Target Enter
    }
}

function Get-MiniTmuxPane {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Target = "main:0.0",

        [int]$Lines = 50
    )

    $output = & $Script:TmuxExe capture-pane -p -t $Target -S "-$Lines"
    return $output
}

function Save-MiniTmuxSession {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )

    & $Script:MtmuxPs1 save $Path
}

function Restore-MiniTmuxSession {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )

    & $Script:MtmuxPs1 restore $Path
}

function Get-MiniTmuxTheme {
    [CmdletBinding()]
    param()

    & $Script:MtmuxPs1 theme list
}

function Set-MiniTmuxTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )

    & $Script:MtmuxPs1 theme $Name
}

function Test-MiniTmux {
    [CmdletBinding()]
    param()

    & $Script:MtmuxPs1 doctor
}

function Switch-MiniTmuxSession {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )

    if ($Name) {
        & $Script:MtmuxPs1 switch $Name
    } else {
        & $Script:MtmuxPs1 switch
    }
}

function Get-MiniTmuxInspect {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Session,

        [switch]$Json
    )

    $callArgs = @('inspect')
    if ($Session) { $callArgs += $Session }
    if ($Json) { $callArgs += '--json' }
    & $Script:MtmuxPs1 @callArgs
}

function Register-MiniTmuxCompletions {
    [CmdletBinding()]
    param()

    if (Get-Command Register-ArgumentCompleter -ErrorAction SilentlyContinue) {
        $completerBlock = {
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
                $sessions = & $Script:TmuxExe list-sessions -F "#{session_name}" 2>$null
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
                $themeDir = Join-Path $Script:MiniTmuxRoot 'etc\themes'
                if (Test-Path $themeDir) {
                    $themes = (Get-ChildItem $themeDir -Filter "*.conf" | Where-Object { $_.BaseName -ne 'current' } | ForEach-Object { $_.BaseName })
                    return ($themes | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Theme: $_")
                    })
                }
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

        Register-ArgumentCompleter -Native -CommandName 'mtmux' -ScriptBlock $completerBlock
        Register-ArgumentCompleter -Native -CommandName 'mtmux.cmd' -ScriptBlock $completerBlock
        Register-ArgumentCompleter -Native -CommandName 'mtmux.ps1' -ScriptBlock $completerBlock
    }
}

# Automatically register argument completions on module load
Register-MiniTmuxCompletions

Export-ModuleMember -Function `
    Get-MiniTmuxSession, `
    New-MiniTmuxSession, `
    Remove-MiniTmuxSession, `
    Send-MiniTmuxKeys, `
    Get-MiniTmuxPane, `
    Switch-MiniTmuxSession, `
    Get-MiniTmuxInspect, `
    Save-MiniTmuxSession, `
    Restore-MiniTmuxSession, `
    Get-MiniTmuxTheme, `
    Set-MiniTmuxTheme, `
    Test-MiniTmux, `
    Register-MiniTmuxCompletions
