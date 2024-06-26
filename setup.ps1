# Installs modules

# Check if these are installed if not reinstall them
if (-not (Get-Module -Name zoxide -ListAvailable)) {
    Install-Module -Name zoxide -Scope AllUsers -Force -AllowClobber
}

if (-not (Get-Module -Name chocolatey -ListAvailable)) {
    Install-Module -Name chocolatey -Scope AllUsers -Force -AllowClobber
}

if (-not (Get-Module -Name fzf -ListAvailable)) {
    Install-Module -Name fzf -Scope AllUsers -Force -AllowClobber
}
# Sets up the PowerShell profile

$gitRepoPath = Get-Location

$symlinkParams = @{
    Path = $PROFILE
    Value = "$gitRepoPath/Microsoft.PowerShell_profile.ps1"
    ItemType = 'SymbolicLink'
    Force = $true
  }

New-Item @symlinkParams

# Setup Windows Terminal Color Configuration
$appDataPackages = "$env:LOCALAPPDATA\Packages"
$terminalSettingsPath = Get-ChildItem -Path $appDataPackages\*Microsoft.WindowsTerminal_*\LocalState\settings.json

# Parse the settings.json file to update the color scheme
$settings = Get-Content -Path $terminalSettingsPath -Raw | ConvertFrom-Json
$frappeScheme = Get-Content -Path "$gitRepoPath/frappe.json" -Raw | ConvertFrom-Json
$frappeTheme = Get-Content -Path "$gitRepoPath/frappeTheme.json" -Raw | ConvertFrom-Json

$settings.profiles.defaults.colorScheme = "Catppuccin Frappe"
$settings.schemes += $frappeScheme
$settings.themes += $frappeTheme

$settings | ConvertTo-Json -Depth 100 | Set-Content -Path $terminalSettingsPath -Force
