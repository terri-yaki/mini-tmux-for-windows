<#
.SYNOPSIS
    MiniTmux PowerShell Module
.DESCRIPTION
    Provides native PowerShell cmdlets to interact with and automate MiniTmux sessions,
    windows, panes, and multi-agent workflows.
#>

$Script:MiniTmuxRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Script:TmuxExe = Join-Path $Script:MiniTmuxRoot 'usr\bin\tmux.exe'
$Script:MtmuxPs1 = Join-Path $Script:MiniTmuxRoot 'bin\mtmux.ps1'

# Ensure noglob is set for all sessions
$env:MSYS = 'noglob'

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

function Test-MiniTmux {
    [CmdletBinding()]
    param()

    & $Script:MtmuxPs1 doctor
}

Export-ModuleMember -Function Get-MiniTmuxSession, New-MiniTmuxSession, Remove-MiniTmuxSession, Send-MiniTmuxKeys, Get-MiniTmuxPane, Test-MiniTmux
