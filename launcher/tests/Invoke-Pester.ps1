#requires -Version 5.1
# Installs Pester 5 for the current user if absent, then runs the launcher suite.
if (-not (Get-Module -ListAvailable -Name Pester |
          Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0.0
}
Import-Module Pester -MinimumVersion 5.0.0 -Force
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = New-PesterConfiguration
$config.Run.Path = $here
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
