#requires -Version 5.1
# Installs Pester 5 for the current user if absent, then runs the launcher suite.
if (-not (Get-Module -ListAvailable -Name Pester |
          Where-Object { $_.Version -ge [version]'5.0.0' })) {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0.0
}
Import-Module Pester -MinimumVersion 5.0.0 -Force
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = New-PesterConfiguration
$config.Run.Path = $here
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
