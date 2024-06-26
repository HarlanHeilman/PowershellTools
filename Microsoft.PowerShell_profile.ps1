using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# =============================================================================
#
# Utility functions for zoxide.
#

# Call zoxide binary, returning the output as UTF-8.
function global:__zoxide_bin {
    $encoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Utf8Encoding]::new()
        $result = zoxide @args
        return $result
    }
    finally {
        [Console]::OutputEncoding = $encoding
    }
}

# pwd based on zoxide's format.
function global:__zoxide_pwd {
    $cwd = Get-Location
    if ($cwd.Provider.Name -eq "FileSystem") {
        $cwd.ProviderPath
    }
}

# cd + custom logic based on the value of _ZO_ECHO.
function global:__zoxide_cd($dir, $literal) {
    $dir = if ($literal) {
        Set-Location -LiteralPath $dir -Passthru -ErrorAction Stop
    }
    else {
        if ($dir -eq '-' -and ($PSVersionTable.PSVersion -lt 6.1)) {
            Write-Error "cd - is not supported below PowerShell 6.1. Please upgrade your version of PowerShell."
        }
        elseif ($dir -eq '+' -and ($PSVersionTable.PSVersion -lt 6.2)) {
            Write-Error "cd + is not supported below PowerShell 6.2. Please upgrade your version of PowerShell."
        }
        else {
            Set-Location -Path $dir -Passthru -ErrorAction Stop
        }
    }
}

# =============================================================================
#
# Hook configuration for zoxide.
#

# Hook to add new entries to the database.
$global:__zoxide_oldpwd = __zoxide_pwd
function global:__zoxide_hook {
    $result = __zoxide_pwd
    if ($result -ne $global:__zoxide_oldpwd) {
        if ($null -ne $result) {
            zoxide add -- $result
        }
        $global:__zoxide_oldpwd = $result
    }
}

# Initialize hook.
$global:__zoxide_hooked = (Get-Variable __zoxide_hooked -ErrorAction SilentlyContinue -ValueOnly)
if ($global:__zoxide_hooked -ne 1) {
    $global:__zoxide_hooked = 1
    $global:__zoxide_prompt_old = $function:prompt

    function global:prompt {
        if ($null -ne $__zoxide_prompt_old) {
            & $__zoxide_prompt_old
        }
        $null = __zoxide_hook
    }
}

# =============================================================================
#
# When using zoxide with --no-cmd, alias these internal functions as desired.
#

# Jump to a directory using only keywords.
function global:__zoxide_z {
    if ($args.Length -eq 0) {
        __zoxide_cd ~ $true
    }
    elseif ($args.Length -eq 1 -and ($args[0] -eq '-' -or $args[0] -eq '+')) {
        __zoxide_cd $args[0] $false
    }
    elseif ($args.Length -eq 1 -and (Test-Path $args[0] -PathType Container)) {
        __zoxide_cd $args[0] $true
    }
    else {
        $result = __zoxide_pwd
        if ($null -ne $result) {
            $result = __zoxide_bin query --exclude $result -- @args
        }
        else {
            $result = __zoxide_bin query -- @args
        }
        if ($LASTEXITCODE -eq 0) {
            __zoxide_cd $result $true
        }
    }
}

# Jump to a directory using interactive search.
function global:__zoxide_zi {
    $result = __zoxide_bin query -i -- @args
    if ($LASTEXITCODE -eq 0) {
        __zoxide_cd $result $true
    }
}

# =============================================================================
#
# Commands for zoxide. Disable these using --no-cmd.
#

Set-Alias -Name cd -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name cdi -Value __zoxide_zi -Option AllScope -Scope Global -Force

# =============================================================================
#
# To initialize zoxide, add this to your configuration (find it by running
# `echo $profile` in PowerShell):
#
$env:VIRTUAL_ENV_DISABLE_PROMPT = 1
Invoke-Expression (& { (zoxide init powershell | Out-String) })
oh-my-posh init pwsh --config "$env:HOME\PowershellTools\catppuccin_frappe.omp.json" | Invoke-Expression

#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
If (Test-Path "C:\tools\mambaforge\Scripts\conda.exe") {
    (& "C:\tools\mambaforge\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ? { $_ } | Invoke-Expression
}
#endregion

# =============================================================================
#
# Sharepoint env variables
#

#region SharePoint Environment Variables
$sp = Convert-Path ("$env:HOMEPATH\Washington State University (email.wsu.edu)\Carbon Lab Research Group - Documents")
$sp = $sp | Add-Member -NotePropertyName root -NotePropertyValue (Convert-Path $sp) -PassThru
$sp = $sp | Add-Member -NotePropertyName user -NotePropertyValue (Convert-Path ($sp + "\\Harlan Heilman")) -PassThru
$sp = $sp | Add-Member -NotePropertyName db -NotePropertyValue (Convert-Path ($sp.User + "\\.refl\\.db")) -PassThru
$sp = $sp | Add-Member -NotePropertyName raw -NotePropertyValue (Convert-Path ($sp + "\\Synchrotron Logistics and Data")) -PassThru


#endregion

# =============================================================================
#
# uv compleations

Register-ArgumentCompleter -Native -CommandName 'uv' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commandElements = $commandAst.CommandElements
    $command = @(
        'uv'
        for ($i = 1; $i -lt $commandElements.Count; $i++) {
            $element = $commandElements[$i]
            if ($element -isnot [StringConstantExpressionAst] -or
                $element.StringConstantType -ne [StringConstantType]::BareWord -or
                $element.Value.StartsWith('-') -or
                $element.Value -eq $wordToComplete) {
                break
            }
            $element.Value
        }) -join ';'

    $completions = @(switch ($command) {
            'uv' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--config-file', 'config-file', [CompletionResultType]::ParameterName, 'The path to a `pyproject.toml` or `uv.toml` file to use for configuration')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--isolated', 'isolated', [CompletionResultType]::ParameterName, 'Avoid discovering a `pyproject.toml` or `uv.toml` file in the current directory or any parent directories')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('pip', 'pip', [CompletionResultType]::ParameterValue, 'Resolve and install Python packages')
                [CompletionResult]::new('venv', 'venv', [CompletionResultType]::ParameterValue, 'Create a virtual environment')
                [CompletionResult]::new('cache', 'cache', [CompletionResultType]::ParameterValue, 'Manage the cache')
                [CompletionResult]::new('self', 'self', [CompletionResultType]::ParameterValue, 'Manage the `uv` executable')
                [CompletionResult]::new('clean', 'clean', [CompletionResultType]::ParameterValue, 'Clear the cache, removing all entries or those linked to specific packages')
                [CompletionResult]::new('run', 'run', [CompletionResultType]::ParameterValue, 'run')
                [CompletionResult]::new('version', 'version', [CompletionResultType]::ParameterValue, 'Display uv''s version')
                [CompletionResult]::new('generate-shell-completion', 'generate-shell-completion', [CompletionResultType]::ParameterValue, 'Generate shell completion')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;pip' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('compile', 'compile', [CompletionResultType]::ParameterValue, 'Compile a `requirements.in` file to a `requirements.txt` file')
                [CompletionResult]::new('sync', 'sync', [CompletionResultType]::ParameterValue, 'Sync dependencies from a `requirements.txt` file')
                [CompletionResult]::new('install', 'install', [CompletionResultType]::ParameterValue, 'Install packages into the current environment')
                [CompletionResult]::new('uninstall', 'uninstall', [CompletionResultType]::ParameterValue, 'Uninstall packages from the current environment')
                [CompletionResult]::new('freeze', 'freeze', [CompletionResultType]::ParameterValue, 'Enumerate the installed packages in the current environment')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Enumerate the installed packages in the current environment')
                [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Show information about one or more installed packages')
                [CompletionResult]::new('check', 'check', [CompletionResultType]::ParameterValue, 'Verify installed packages have compatible dependencies')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;pip;compile' {
                [CompletionResult]::new('-c', 'c', [CompletionResultType]::ParameterName, 'Constrain versions using the given requirements files')
                [CompletionResult]::new('--constraint', 'constraint', [CompletionResultType]::ParameterName, 'Constrain versions using the given requirements files')
                [CompletionResult]::new('--override', 'override', [CompletionResultType]::ParameterName, 'Override versions using the given requirements files')
                [CompletionResult]::new('--extra', 'extra', [CompletionResultType]::ParameterName, 'Include optional dependencies in the given extra group name; may be provided more than once')
                [CompletionResult]::new('--resolution', 'resolution', [CompletionResultType]::ParameterName, 'The strategy to use when selecting between the different compatible versions for a given package requirement')
                [CompletionResult]::new('--prerelease', 'prerelease', [CompletionResultType]::ParameterName, 'The strategy to use when considering pre-release versions')
                [CompletionResult]::new('-o', 'o', [CompletionResultType]::ParameterName, 'Write the compiled requirements to the given `requirements.txt` file')
                [CompletionResult]::new('--output-file', 'output-file', [CompletionResultType]::ParameterName, 'Write the compiled requirements to the given `requirements.txt` file')
                [CompletionResult]::new('--annotation-style', 'annotation-style', [CompletionResultType]::ParameterName, 'Choose the style of the annotation comments, which indicate the source of each package')
                [CompletionResult]::new('--custom-compile-command', 'custom-compile-command', [CompletionResultType]::ParameterName, 'Change header comment to reflect custom command wrapping `uv pip compile`')
                [CompletionResult]::new('--refresh-package', 'refresh-package', [CompletionResultType]::ParameterName, 'Refresh cached data for a specific package')
                [CompletionResult]::new('--link-mode', 'link-mode', [CompletionResultType]::ParameterName, 'The method to use when installing packages from the global cache')
                [CompletionResult]::new('-i', 'i', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--index-url', 'index-url', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--extra-index-url', 'extra-index-url', [CompletionResultType]::ParameterName, 'Extra URLs of package indexes to use, in addition to `--index-url`')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Locations to search for candidate distributions, beyond those found in the indexes')
                [CompletionResult]::new('--find-links', 'find-links', [CompletionResultType]::ParameterName, 'Locations to search for candidate distributions, beyond those found in the indexes')
                [CompletionResult]::new('--index-strategy', 'index-strategy', [CompletionResultType]::ParameterName, 'The strategy to use when resolving against multiple index URLs')
                [CompletionResult]::new('--keyring-provider', 'keyring-provider', [CompletionResultType]::ParameterName, 'Attempt to use `keyring` for authentication for index URLs')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter against which to compile the requirements.')
                [CompletionResult]::new('-P', 'P ', [CompletionResultType]::ParameterName, 'Allow upgrades for a specific package, ignoring pinned versions in the existing output file')
                [CompletionResult]::new('--upgrade-package', 'upgrade-package', [CompletionResultType]::ParameterName, 'Allow upgrades for a specific package, ignoring pinned versions in the existing output file')
                [CompletionResult]::new('--only-binary', 'only-binary', [CompletionResultType]::ParameterName, 'Only use pre-built wheels; don''t build source distributions')
                [CompletionResult]::new('-C', 'C ', [CompletionResultType]::ParameterName, 'Settings to pass to the PEP 517 build backend, specified as `KEY=VALUE` pairs')
                [CompletionResult]::new('--config-setting', 'config-setting', [CompletionResultType]::ParameterName, 'Settings to pass to the PEP 517 build backend, specified as `KEY=VALUE` pairs')
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The minimum Python version that should be supported by the compiled requirements (e.g., `3.7` or `3.7.9`)')
                [CompletionResult]::new('--python-version', 'python-version', [CompletionResultType]::ParameterName, 'The minimum Python version that should be supported by the compiled requirements (e.g., `3.7` or `3.7.9`)')
                [CompletionResult]::new('--python-platform', 'python-platform', [CompletionResultType]::ParameterName, 'The platform for which requirements should be resolved')
                [CompletionResult]::new('--exclude-newer', 'exclude-newer', [CompletionResultType]::ParameterName, 'Limit candidate packages to those that were uploaded prior to the given date')
                [CompletionResult]::new('--no-emit-package', 'no-emit-package', [CompletionResultType]::ParameterName, 'Specify a package to omit from the output resolution. Its dependencies will still be included in the resolution. Equivalent to pip-compile''s `--unsafe-package` option')
                [CompletionResult]::new('--resolver', 'resolver', [CompletionResultType]::ParameterName, 'resolver')
                [CompletionResult]::new('--max-rounds', 'max-rounds', [CompletionResultType]::ParameterName, 'max-rounds')
                [CompletionResult]::new('--cert', 'cert', [CompletionResultType]::ParameterName, 'cert')
                [CompletionResult]::new('--client-cert', 'client-cert', [CompletionResultType]::ParameterName, 'client-cert')
                [CompletionResult]::new('--trusted-host', 'trusted-host', [CompletionResultType]::ParameterName, 'trusted-host')
                [CompletionResult]::new('--config', 'config', [CompletionResultType]::ParameterName, 'config')
                [CompletionResult]::new('--pip-args', 'pip-args', [CompletionResultType]::ParameterName, 'pip-args')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--all-extras', 'all-extras', [CompletionResultType]::ParameterName, 'Include all optional dependencies')
                [CompletionResult]::new('--no-all-extras', 'no-all-extras', [CompletionResultType]::ParameterName, 'no-all-extras')
                [CompletionResult]::new('--no-deps', 'no-deps', [CompletionResultType]::ParameterName, 'Ignore package dependencies, instead only add those packages explicitly listed on the command line to the resulting the requirements file')
                [CompletionResult]::new('--deps', 'deps', [CompletionResultType]::ParameterName, 'deps')
                [CompletionResult]::new('--pre', 'pre', [CompletionResultType]::ParameterName, 'pre')
                [CompletionResult]::new('--no-strip-extras', 'no-strip-extras', [CompletionResultType]::ParameterName, 'Include extras in the output file')
                [CompletionResult]::new('--strip-extras', 'strip-extras', [CompletionResultType]::ParameterName, 'strip-extras')
                [CompletionResult]::new('--no-annotate', 'no-annotate', [CompletionResultType]::ParameterName, 'Exclude comment annotations indicating the source of each package')
                [CompletionResult]::new('--annotate', 'annotate', [CompletionResultType]::ParameterName, 'annotate')
                [CompletionResult]::new('--no-header', 'no-header', [CompletionResultType]::ParameterName, 'Exclude the comment header at the top of the generated output file')
                [CompletionResult]::new('--header', 'header', [CompletionResultType]::ParameterName, 'header')
                [CompletionResult]::new('--offline', 'offline', [CompletionResultType]::ParameterName, 'Run offline, i.e., without accessing the network')
                [CompletionResult]::new('--no-offline', 'no-offline', [CompletionResultType]::ParameterName, 'no-offline')
                [CompletionResult]::new('--refresh', 'refresh', [CompletionResultType]::ParameterName, 'Refresh all cached data')
                [CompletionResult]::new('--no-index', 'no-index', [CompletionResultType]::ParameterName, 'Ignore the registry index (e.g., PyPI), instead relying on direct URL dependencies and those discovered via `--find-links`')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'Install packages into the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('-U', 'U ', [CompletionResultType]::ParameterName, 'Allow package upgrades, ignoring pinned versions in the existing output file')
                [CompletionResult]::new('--upgrade', 'upgrade', [CompletionResultType]::ParameterName, 'Allow package upgrades, ignoring pinned versions in the existing output file')
                [CompletionResult]::new('--generate-hashes', 'generate-hashes', [CompletionResultType]::ParameterName, 'Include distribution hashes in the output file')
                [CompletionResult]::new('--no-generate-hashes', 'no-generate-hashes', [CompletionResultType]::ParameterName, 'no-generate-hashes')
                [CompletionResult]::new('--legacy-setup-py', 'legacy-setup-py', [CompletionResultType]::ParameterName, 'Use legacy `setuptools` behavior when building source distributions without a `pyproject.toml`')
                [CompletionResult]::new('--no-legacy-setup-py', 'no-legacy-setup-py', [CompletionResultType]::ParameterName, 'no-legacy-setup-py')
                [CompletionResult]::new('--no-build-isolation', 'no-build-isolation', [CompletionResultType]::ParameterName, 'Disable isolation when building source distributions')
                [CompletionResult]::new('--build-isolation', 'build-isolation', [CompletionResultType]::ParameterName, 'build-isolation')
                [CompletionResult]::new('--no-build', 'no-build', [CompletionResultType]::ParameterName, 'Don''t build source distributions')
                [CompletionResult]::new('--build', 'build', [CompletionResultType]::ParameterName, 'build')
                [CompletionResult]::new('--emit-index-url', 'emit-index-url', [CompletionResultType]::ParameterName, 'Include `--index-url` and `--extra-index-url` entries in the generated output file')
                [CompletionResult]::new('--no-emit-index-url', 'no-emit-index-url', [CompletionResultType]::ParameterName, 'no-emit-index-url')
                [CompletionResult]::new('--emit-find-links', 'emit-find-links', [CompletionResultType]::ParameterName, 'Include `--find-links` entries in the generated output file')
                [CompletionResult]::new('--no-emit-find-links', 'no-emit-find-links', [CompletionResultType]::ParameterName, 'no-emit-find-links')
                [CompletionResult]::new('--emit-marker-expression', 'emit-marker-expression', [CompletionResultType]::ParameterName, 'Whether to emit a marker string indicating when it is known that the resulting set of pinned dependencies is valid')
                [CompletionResult]::new('--no-emit-marker-expression', 'no-emit-marker-expression', [CompletionResultType]::ParameterName, 'no-emit-marker-expression')
                [CompletionResult]::new('--emit-index-annotation', 'emit-index-annotation', [CompletionResultType]::ParameterName, 'Include comment annotations indicating the index used to resolve each package (e.g., `# from https://pypi.org/simple`)')
                [CompletionResult]::new('--no-emit-index-annotation', 'no-emit-index-annotation', [CompletionResultType]::ParameterName, 'no-emit-index-annotation')
                [CompletionResult]::new('--allow-unsafe', 'allow-unsafe', [CompletionResultType]::ParameterName, 'allow-unsafe')
                [CompletionResult]::new('--no-allow-unsafe', 'no-allow-unsafe', [CompletionResultType]::ParameterName, 'no-allow-unsafe')
                [CompletionResult]::new('--reuse-hashes', 'reuse-hashes', [CompletionResultType]::ParameterName, 'reuse-hashes')
                [CompletionResult]::new('--no-reuse-hashes', 'no-reuse-hashes', [CompletionResultType]::ParameterName, 'no-reuse-hashes')
                [CompletionResult]::new('--emit-trusted-host', 'emit-trusted-host', [CompletionResultType]::ParameterName, 'emit-trusted-host')
                [CompletionResult]::new('--no-emit-trusted-host', 'no-emit-trusted-host', [CompletionResultType]::ParameterName, 'no-emit-trusted-host')
                [CompletionResult]::new('--no-config', 'no-config', [CompletionResultType]::ParameterName, 'no-config')
                [CompletionResult]::new('--emit-options', 'emit-options', [CompletionResultType]::ParameterName, 'emit-options')
                [CompletionResult]::new('--no-emit-options', 'no-emit-options', [CompletionResultType]::ParameterName, 'no-emit-options')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;sync' {
                [CompletionResult]::new('--reinstall-package', 'reinstall-package', [CompletionResultType]::ParameterName, 'Reinstall a specific package, regardless of whether it''s already installed')
                [CompletionResult]::new('--refresh-package', 'refresh-package', [CompletionResultType]::ParameterName, 'Refresh cached data for a specific package')
                [CompletionResult]::new('--link-mode', 'link-mode', [CompletionResultType]::ParameterName, 'The method to use when installing packages from the global cache')
                [CompletionResult]::new('-i', 'i', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--index-url', 'index-url', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--extra-index-url', 'extra-index-url', [CompletionResultType]::ParameterName, 'Extra URLs of package indexes to use, in addition to `--index-url`')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Locations to search for candidate distributions, beyond those found in the indexes')
                [CompletionResult]::new('--find-links', 'find-links', [CompletionResultType]::ParameterName, 'Locations to search for candidate distributions, beyond those found in the indexes')
                [CompletionResult]::new('--index-strategy', 'index-strategy', [CompletionResultType]::ParameterName, 'The strategy to use when resolving against multiple index URLs')
                [CompletionResult]::new('--keyring-provider', 'keyring-provider', [CompletionResultType]::ParameterName, 'Attempt to use `keyring` for authentication for index URLs')
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter into which packages should be installed.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter into which packages should be installed.')
                [CompletionResult]::new('--target', 'target', [CompletionResultType]::ParameterName, 'Install packages into the specified directory, rather than into the virtual environment or system Python interpreter')
                [CompletionResult]::new('--no-binary', 'no-binary', [CompletionResultType]::ParameterName, 'Don''t install pre-built wheels')
                [CompletionResult]::new('--only-binary', 'only-binary', [CompletionResultType]::ParameterName, 'Only use pre-built wheels; don''t build source distributions')
                [CompletionResult]::new('-C', 'C ', [CompletionResultType]::ParameterName, 'Settings to pass to the PEP 517 build backend, specified as `KEY=VALUE` pairs')
                [CompletionResult]::new('--config-setting', 'config-setting', [CompletionResultType]::ParameterName, 'Settings to pass to the PEP 517 build backend, specified as `KEY=VALUE` pairs')
                [CompletionResult]::new('--python-version', 'python-version', [CompletionResultType]::ParameterName, 'The minimum Python version that should be supported by the requirements (e.g., `3.7` or `3.7.9`)')
                [CompletionResult]::new('--python-platform', 'python-platform', [CompletionResultType]::ParameterName, 'The platform for which requirements should be installed')
                [CompletionResult]::new('--trusted-host', 'trusted-host', [CompletionResultType]::ParameterName, 'trusted-host')
                [CompletionResult]::new('--python-executable', 'python-executable', [CompletionResultType]::ParameterName, 'python-executable')
                [CompletionResult]::new('--cert', 'cert', [CompletionResultType]::ParameterName, 'cert')
                [CompletionResult]::new('--client-cert', 'client-cert', [CompletionResultType]::ParameterName, 'client-cert')
                [CompletionResult]::new('--config', 'config', [CompletionResultType]::ParameterName, 'config')
                [CompletionResult]::new('--pip-args', 'pip-args', [CompletionResultType]::ParameterName, 'pip-args')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--reinstall', 'reinstall', [CompletionResultType]::ParameterName, 'Reinstall all packages, regardless of whether they''re already installed')
                [CompletionResult]::new('--offline', 'offline', [CompletionResultType]::ParameterName, 'offline')
                [CompletionResult]::new('--no-offline', 'no-offline', [CompletionResultType]::ParameterName, 'no-offline')
                [CompletionResult]::new('--refresh', 'refresh', [CompletionResultType]::ParameterName, 'Refresh all cached data')
                [CompletionResult]::new('--no-index', 'no-index', [CompletionResultType]::ParameterName, 'Ignore the registry index (e.g., PyPI), instead relying on direct URL dependencies and those discovered via `--find-links`')
                [CompletionResult]::new('--require-hashes', 'require-hashes', [CompletionResultType]::ParameterName, 'Require a matching hash for each requirement')
                [CompletionResult]::new('--no-require-hashes', 'no-require-hashes', [CompletionResultType]::ParameterName, 'no-require-hashes')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'Install packages into the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('--break-system-packages', 'break-system-packages', [CompletionResultType]::ParameterName, 'Allow `uv` to modify an `EXTERNALLY-MANAGED` Python installation')
                [CompletionResult]::new('--no-break-system-packages', 'no-break-system-packages', [CompletionResultType]::ParameterName, 'no-break-system-packages')
                [CompletionResult]::new('--legacy-setup-py', 'legacy-setup-py', [CompletionResultType]::ParameterName, 'Use legacy `setuptools` behavior when building source distributions without a `pyproject.toml`')
                [CompletionResult]::new('--no-legacy-setup-py', 'no-legacy-setup-py', [CompletionResultType]::ParameterName, 'no-legacy-setup-py')
                [CompletionResult]::new('--no-build-isolation', 'no-build-isolation', [CompletionResultType]::ParameterName, 'Disable isolation when building source distributions')
                [CompletionResult]::new('--build-isolation', 'build-isolation', [CompletionResultType]::ParameterName, 'build-isolation')
                [CompletionResult]::new('--no-build', 'no-build', [CompletionResultType]::ParameterName, 'Don''t build source distributions')
                [CompletionResult]::new('--build', 'build', [CompletionResultType]::ParameterName, 'build')
                [CompletionResult]::new('--compile-bytecode', 'compile-bytecode', [CompletionResultType]::ParameterName, 'Compile Python files to bytecode')
                [CompletionResult]::new('--no-compile-bytecode', 'no-compile-bytecode', [CompletionResultType]::ParameterName, 'no-compile-bytecode')
                [CompletionResult]::new('--strict', 'strict', [CompletionResultType]::ParameterName, 'Validate the virtual environment after completing the installation, to detect packages with missing dependencies or other issues')
                [CompletionResult]::new('--no-strict', 'no-strict', [CompletionResultType]::ParameterName, 'no-strict')
                [CompletionResult]::new('-a', 'a', [CompletionResultType]::ParameterName, 'a')
                [CompletionResult]::new('--ask', 'ask', [CompletionResultType]::ParameterName, 'ask')
                [CompletionResult]::new('--user', 'user', [CompletionResultType]::ParameterName, 'user')
                [CompletionResult]::new('--no-config', 'no-config', [CompletionResultType]::ParameterName, 'no-config')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;install' {
                [CompletionResult]::new('-r', 'r', [CompletionResultType]::ParameterName, 'Install all packages listed in the given requirements files')
                [CompletionResult]::new('--requirement', 'requirement', [CompletionResultType]::ParameterName, 'Install all packages listed in the given requirements files')
                [CompletionResult]::new('-e', 'e', [CompletionResultType]::ParameterName, 'Install the editable package based on the provided local file path')
                [CompletionResult]::new('--editable', 'editable', [CompletionResultType]::ParameterName, 'Install the editable package based on the provided local file path')
                [CompletionResult]::new('-c', 'c', [CompletionResultType]::ParameterName, 'Constrain versions using the given requirements files')
                [CompletionResult]::new('--constraint', 'constraint', [CompletionResultType]::ParameterName, 'Constrain versions using the given requirements files')
                [CompletionResult]::new('--override', 'override', [CompletionResultType]::ParameterName, 'Override versions using the given requirements files')
                [CompletionResult]::new('--extra', 'extra', [CompletionResultType]::ParameterName, 'Include optional dependencies in the given extra group name; may be provided more than once')
                [CompletionResult]::new('-P', 'P ', [CompletionResultType]::ParameterName, 'Allow upgrade of a specific package')
                [CompletionResult]::new('--upgrade-package', 'upgrade-package', [CompletionResultType]::ParameterName, 'Allow upgrade of a specific package')
                [CompletionResult]::new('--reinstall-package', 'reinstall-package', [CompletionResultType]::ParameterName, 'Reinstall a specific package, regardless of whether it''s already installed')
                [CompletionResult]::new('--refresh-package', 'refresh-package', [CompletionResultType]::ParameterName, 'Refresh cached data for a specific package')
                [CompletionResult]::new('--link-mode', 'link-mode', [CompletionResultType]::ParameterName, 'The method to use when installing packages from the global cache')
                [CompletionResult]::new('--resolution', 'resolution', [CompletionResultType]::ParameterName, 'The strategy to use when selecting between the different compatible versions for a given package requirement')
                [CompletionResult]::new('--prerelease', 'prerelease', [CompletionResultType]::ParameterName, 'The strategy to use when considering pre-release versions')
                [CompletionResult]::new('-i', 'i', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--index-url', 'index-url', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--extra-index-url', 'extra-index-url', [CompletionResultType]::ParameterName, 'Extra URLs of package indexes to use, in addition to `--index-url`')
                [CompletionResult]::new('-f', 'f', [CompletionResultType]::ParameterName, 'Locations to search for candidate distributions, beyond those found in the indexes')
                [CompletionResult]::new('--find-links', 'find-links', [CompletionResultType]::ParameterName, 'Locations to search for candidate distributions, beyond those found in the indexes')
                [CompletionResult]::new('--index-strategy', 'index-strategy', [CompletionResultType]::ParameterName, 'The strategy to use when resolving against multiple index URLs')
                [CompletionResult]::new('--keyring-provider', 'keyring-provider', [CompletionResultType]::ParameterName, 'Attempt to use `keyring` for authentication for index URLs')
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter into which packages should be installed.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter into which packages should be installed.')
                [CompletionResult]::new('--target', 'target', [CompletionResultType]::ParameterName, 'Install packages into the specified directory, rather than into the virtual environment or system Python interpreter')
                [CompletionResult]::new('--no-binary', 'no-binary', [CompletionResultType]::ParameterName, 'Don''t install pre-built wheels')
                [CompletionResult]::new('--only-binary', 'only-binary', [CompletionResultType]::ParameterName, 'Only use pre-built wheels; don''t build source distributions')
                [CompletionResult]::new('-C', 'C ', [CompletionResultType]::ParameterName, 'Settings to pass to the PEP 517 build backend, specified as `KEY=VALUE` pairs')
                [CompletionResult]::new('--config-setting', 'config-setting', [CompletionResultType]::ParameterName, 'Settings to pass to the PEP 517 build backend, specified as `KEY=VALUE` pairs')
                [CompletionResult]::new('--python-version', 'python-version', [CompletionResultType]::ParameterName, 'The minimum Python version that should be supported by the requirements (e.g., `3.7` or `3.7.9`)')
                [CompletionResult]::new('--python-platform', 'python-platform', [CompletionResultType]::ParameterName, 'The platform for which requirements should be installed')
                [CompletionResult]::new('--exclude-newer', 'exclude-newer', [CompletionResultType]::ParameterName, 'Limit candidate packages to those that were uploaded prior to the given date')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--all-extras', 'all-extras', [CompletionResultType]::ParameterName, 'Include all optional dependencies')
                [CompletionResult]::new('--no-all-extras', 'no-all-extras', [CompletionResultType]::ParameterName, 'no-all-extras')
                [CompletionResult]::new('-U', 'U ', [CompletionResultType]::ParameterName, 'Allow package upgrades')
                [CompletionResult]::new('--upgrade', 'upgrade', [CompletionResultType]::ParameterName, 'Allow package upgrades')
                [CompletionResult]::new('--reinstall', 'reinstall', [CompletionResultType]::ParameterName, 'Reinstall all packages, regardless of whether they''re already installed')
                [CompletionResult]::new('--offline', 'offline', [CompletionResultType]::ParameterName, 'offline')
                [CompletionResult]::new('--no-offline', 'no-offline', [CompletionResultType]::ParameterName, 'no-offline')
                [CompletionResult]::new('--refresh', 'refresh', [CompletionResultType]::ParameterName, 'Refresh all cached data')
                [CompletionResult]::new('--no-deps', 'no-deps', [CompletionResultType]::ParameterName, 'Ignore package dependencies, instead only installing those packages explicitly listed on the command line or in the requirements files')
                [CompletionResult]::new('--deps', 'deps', [CompletionResultType]::ParameterName, 'deps')
                [CompletionResult]::new('--pre', 'pre', [CompletionResultType]::ParameterName, 'pre')
                [CompletionResult]::new('--no-index', 'no-index', [CompletionResultType]::ParameterName, 'Ignore the registry index (e.g., PyPI), instead relying on direct URL dependencies and those discovered via `--find-links`')
                [CompletionResult]::new('--require-hashes', 'require-hashes', [CompletionResultType]::ParameterName, 'Require a matching hash for each requirement')
                [CompletionResult]::new('--no-require-hashes', 'no-require-hashes', [CompletionResultType]::ParameterName, 'no-require-hashes')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'Install packages into the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('--break-system-packages', 'break-system-packages', [CompletionResultType]::ParameterName, 'Allow `uv` to modify an `EXTERNALLY-MANAGED` Python installation')
                [CompletionResult]::new('--no-break-system-packages', 'no-break-system-packages', [CompletionResultType]::ParameterName, 'no-break-system-packages')
                [CompletionResult]::new('--legacy-setup-py', 'legacy-setup-py', [CompletionResultType]::ParameterName, 'Use legacy `setuptools` behavior when building source distributions without a `pyproject.toml`')
                [CompletionResult]::new('--no-legacy-setup-py', 'no-legacy-setup-py', [CompletionResultType]::ParameterName, 'no-legacy-setup-py')
                [CompletionResult]::new('--no-build-isolation', 'no-build-isolation', [CompletionResultType]::ParameterName, 'Disable isolation when building source distributions')
                [CompletionResult]::new('--build-isolation', 'build-isolation', [CompletionResultType]::ParameterName, 'build-isolation')
                [CompletionResult]::new('--no-build', 'no-build', [CompletionResultType]::ParameterName, 'Don''t build source distributions')
                [CompletionResult]::new('--build', 'build', [CompletionResultType]::ParameterName, 'build')
                [CompletionResult]::new('--compile-bytecode', 'compile-bytecode', [CompletionResultType]::ParameterName, 'Compile Python files to bytecode')
                [CompletionResult]::new('--no-compile-bytecode', 'no-compile-bytecode', [CompletionResultType]::ParameterName, 'no-compile-bytecode')
                [CompletionResult]::new('--strict', 'strict', [CompletionResultType]::ParameterName, 'Validate the virtual environment after completing the installation, to detect packages with missing dependencies or other issues')
                [CompletionResult]::new('--no-strict', 'no-strict', [CompletionResultType]::ParameterName, 'no-strict')
                [CompletionResult]::new('--dry-run', 'dry-run', [CompletionResultType]::ParameterName, 'Perform a dry run, i.e., don''t actually install anything but resolve the dependencies and print the resulting plan')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;uninstall' {
                [CompletionResult]::new('-r', 'r', [CompletionResultType]::ParameterName, 'Uninstall all packages listed in the given requirements files')
                [CompletionResult]::new('--requirement', 'requirement', [CompletionResultType]::ParameterName, 'Uninstall all packages listed in the given requirements files')
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter from which packages should be uninstalled.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter from which packages should be uninstalled.')
                [CompletionResult]::new('--keyring-provider', 'keyring-provider', [CompletionResultType]::ParameterName, 'Attempt to use `keyring` for authentication for remote requirements files')
                [CompletionResult]::new('--target', 'target', [CompletionResultType]::ParameterName, 'Uninstall packages from the specified directory, rather than from the virtual environment or system Python interpreter')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'Use the system Python to uninstall packages')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('--break-system-packages', 'break-system-packages', [CompletionResultType]::ParameterName, 'Allow `uv` to modify an `EXTERNALLY-MANAGED` Python installation')
                [CompletionResult]::new('--no-break-system-packages', 'no-break-system-packages', [CompletionResultType]::ParameterName, 'no-break-system-packages')
                [CompletionResult]::new('--offline', 'offline', [CompletionResultType]::ParameterName, 'Run offline, i.e., without accessing the network')
                [CompletionResult]::new('--no-offline', 'no-offline', [CompletionResultType]::ParameterName, 'no-offline')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;freeze' {
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--exclude-editable', 'exclude-editable', [CompletionResultType]::ParameterName, 'Exclude any editable packages from output')
                [CompletionResult]::new('--strict', 'strict', [CompletionResultType]::ParameterName, 'Validate the virtual environment, to detect packages with missing dependencies or other issues')
                [CompletionResult]::new('--no-strict', 'no-strict', [CompletionResultType]::ParameterName, 'no-strict')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'List packages for the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;list' {
                [CompletionResult]::new('--exclude', 'exclude', [CompletionResultType]::ParameterName, 'Exclude the specified package(s) from the output')
                [CompletionResult]::new('--format', 'format', [CompletionResultType]::ParameterName, 'Select the output format between: `columns` (default), `freeze`, or `json`')
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-e', 'e', [CompletionResultType]::ParameterName, 'Only include editable projects')
                [CompletionResult]::new('--editable', 'editable', [CompletionResultType]::ParameterName, 'Only include editable projects')
                [CompletionResult]::new('--exclude-editable', 'exclude-editable', [CompletionResultType]::ParameterName, 'Exclude any editable packages from output')
                [CompletionResult]::new('--strict', 'strict', [CompletionResultType]::ParameterName, 'Validate the virtual environment, to detect packages with missing dependencies or other issues')
                [CompletionResult]::new('--no-strict', 'no-strict', [CompletionResultType]::ParameterName, 'no-strict')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'List packages for the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('--outdated', 'outdated', [CompletionResultType]::ParameterName, 'outdated')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;show' {
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--strict', 'strict', [CompletionResultType]::ParameterName, 'Validate the virtual environment, to detect packages with missing dependencies or other issues')
                [CompletionResult]::new('--no-strict', 'no-strict', [CompletionResultType]::ParameterName, 'no-strict')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'List packages for the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;check' {
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter for which packages should be listed.')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'List packages for the system Python')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;pip;help' {
                [CompletionResult]::new('compile', 'compile', [CompletionResultType]::ParameterValue, 'Compile a `requirements.in` file to a `requirements.txt` file')
                [CompletionResult]::new('sync', 'sync', [CompletionResultType]::ParameterValue, 'Sync dependencies from a `requirements.txt` file')
                [CompletionResult]::new('install', 'install', [CompletionResultType]::ParameterValue, 'Install packages into the current environment')
                [CompletionResult]::new('uninstall', 'uninstall', [CompletionResultType]::ParameterValue, 'Uninstall packages from the current environment')
                [CompletionResult]::new('freeze', 'freeze', [CompletionResultType]::ParameterValue, 'Enumerate the installed packages in the current environment')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Enumerate the installed packages in the current environment')
                [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Show information about one or more installed packages')
                [CompletionResult]::new('check', 'check', [CompletionResultType]::ParameterValue, 'Verify installed packages have compatible dependencies')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;pip;help;compile' {
                break
            }
            'uv;pip;help;sync' {
                break
            }
            'uv;pip;help;install' {
                break
            }
            'uv;pip;help;uninstall' {
                break
            }
            'uv;pip;help;freeze' {
                break
            }
            'uv;pip;help;list' {
                break
            }
            'uv;pip;help;show' {
                break
            }
            'uv;pip;help;check' {
                break
            }
            'uv;pip;help;help' {
                break
            }
            'uv;venv' {
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter to use for the virtual environment.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter to use for the virtual environment.')
                [CompletionResult]::new('--prompt', 'prompt', [CompletionResultType]::ParameterName, 'Provide an alternative prompt prefix for the virtual environment.')
                [CompletionResult]::new('--link-mode', 'link-mode', [CompletionResultType]::ParameterName, 'The method to use when installing packages from the global cache')
                [CompletionResult]::new('-i', 'i', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--index-url', 'index-url', [CompletionResultType]::ParameterName, 'The URL of the Python package index (by default: <https://pypi.org/simple>)')
                [CompletionResult]::new('--extra-index-url', 'extra-index-url', [CompletionResultType]::ParameterName, 'Extra URLs of package indexes to use, in addition to `--index-url`')
                [CompletionResult]::new('--index-strategy', 'index-strategy', [CompletionResultType]::ParameterName, 'The strategy to use when resolving against multiple index URLs')
                [CompletionResult]::new('--keyring-provider', 'keyring-provider', [CompletionResultType]::ParameterName, 'Attempt to use `keyring` for authentication for index URLs')
                [CompletionResult]::new('--exclude-newer', 'exclude-newer', [CompletionResultType]::ParameterName, 'Limit candidate packages to those that were uploaded prior to the given date')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--system', 'system', [CompletionResultType]::ParameterName, 'Use the system Python to uninstall packages')
                [CompletionResult]::new('--no-system', 'no-system', [CompletionResultType]::ParameterName, 'no-system')
                [CompletionResult]::new('--seed', 'seed', [CompletionResultType]::ParameterName, 'Install seed packages (`pip`, `setuptools`, and `wheel`) into the virtual environment')
                [CompletionResult]::new('--system-site-packages', 'system-site-packages', [CompletionResultType]::ParameterName, 'Give the virtual environment access to the system site packages directory')
                [CompletionResult]::new('--no-index', 'no-index', [CompletionResultType]::ParameterName, 'Ignore the registry index (e.g., PyPI), instead relying on direct URL dependencies and those discovered via `--find-links`')
                [CompletionResult]::new('--offline', 'offline', [CompletionResultType]::ParameterName, 'Run offline, i.e., without accessing the network')
                [CompletionResult]::new('--no-offline', 'no-offline', [CompletionResultType]::ParameterName, 'no-offline')
                [CompletionResult]::new('--clear', 'clear', [CompletionResultType]::ParameterName, 'clear')
                [CompletionResult]::new('--no-seed', 'no-seed', [CompletionResultType]::ParameterName, 'no-seed')
                [CompletionResult]::new('--no-pip', 'no-pip', [CompletionResultType]::ParameterName, 'no-pip')
                [CompletionResult]::new('--no-setuptools', 'no-setuptools', [CompletionResultType]::ParameterName, 'no-setuptools')
                [CompletionResult]::new('--no-wheel', 'no-wheel', [CompletionResultType]::ParameterName, 'no-wheel')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;cache' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('clean', 'clean', [CompletionResultType]::ParameterValue, 'Clear the cache, removing all entries or those linked to specific packages')
                [CompletionResult]::new('prune', 'prune', [CompletionResultType]::ParameterValue, 'Prune all unreachable objects from the cache')
                [CompletionResult]::new('dir', 'dir', [CompletionResultType]::ParameterValue, 'Show the cache directory')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;cache;clean' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;cache;prune' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;cache;dir' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;cache;help' {
                [CompletionResult]::new('clean', 'clean', [CompletionResultType]::ParameterValue, 'Clear the cache, removing all entries or those linked to specific packages')
                [CompletionResult]::new('prune', 'prune', [CompletionResultType]::ParameterValue, 'Prune all unreachable objects from the cache')
                [CompletionResult]::new('dir', 'dir', [CompletionResultType]::ParameterValue, 'Show the cache directory')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;cache;help;clean' {
                break
            }
            'uv;cache;help;prune' {
                break
            }
            'uv;cache;help;dir' {
                break
            }
            'uv;cache;help;help' {
                break
            }
            'uv;self' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Update `uv` to the latest version')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;self;update' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;self;help' {
                [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Update `uv` to the latest version')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;self;help;update' {
                break
            }
            'uv;self;help;help' {
                break
            }
            'uv;clean' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;run' {
                [CompletionResult]::new('--with', 'with', [CompletionResultType]::ParameterName, 'Run with the given packages installed')
                [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'The Python interpreter to use to build the run environment.')
                [CompletionResult]::new('--python', 'python', [CompletionResultType]::ParameterName, 'The Python interpreter to use to build the run environment.')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('--isolated', 'isolated', [CompletionResultType]::ParameterName, 'Always use a new virtual environment for execution')
                [CompletionResult]::new('--no-workspace', 'no-workspace', [CompletionResultType]::ParameterName, 'Run without the current workspace installed')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;version' {
                [CompletionResult]::new('--output-format', 'output-format', [CompletionResultType]::ParameterName, 'output-format')
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;generate-shell-completion' {
                [CompletionResult]::new('--color', 'color', [CompletionResultType]::ParameterName, 'Control colors in output')
                [CompletionResult]::new('--cache-dir', 'cache-dir', [CompletionResultType]::ParameterName, 'Path to the cache directory')
                [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Do not print any output')
                [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Use verbose output')
                [CompletionResult]::new('--no-color', 'no-color', [CompletionResultType]::ParameterName, 'Disable colors; provided for compatibility with `pip`')
                [CompletionResult]::new('--native-tls', 'native-tls', [CompletionResultType]::ParameterName, 'Whether to load TLS certificates from the platform''s native certificate store')
                [CompletionResult]::new('--no-native-tls', 'no-native-tls', [CompletionResultType]::ParameterName, 'no-native-tls')
                [CompletionResult]::new('--preview', 'preview', [CompletionResultType]::ParameterName, 'Whether to enable experimental, preview features')
                [CompletionResult]::new('--no-preview', 'no-preview', [CompletionResultType]::ParameterName, 'no-preview')
                [CompletionResult]::new('-n', 'n', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('--no-cache', 'no-cache', [CompletionResultType]::ParameterName, 'Avoid reading from or writing to the cache')
                [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
                [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
                [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
                break
            }
            'uv;help' {
                [CompletionResult]::new('pip', 'pip', [CompletionResultType]::ParameterValue, 'Resolve and install Python packages')
                [CompletionResult]::new('venv', 'venv', [CompletionResultType]::ParameterValue, 'Create a virtual environment')
                [CompletionResult]::new('cache', 'cache', [CompletionResultType]::ParameterValue, 'Manage the cache')
                [CompletionResult]::new('self', 'self', [CompletionResultType]::ParameterValue, 'Manage the `uv` executable')
                [CompletionResult]::new('clean', 'clean', [CompletionResultType]::ParameterValue, 'Clear the cache, removing all entries or those linked to specific packages')
                [CompletionResult]::new('run', 'run', [CompletionResultType]::ParameterValue, 'run')
                [CompletionResult]::new('version', 'version', [CompletionResultType]::ParameterValue, 'Display uv''s version')
                [CompletionResult]::new('generate-shell-completion', 'generate-shell-completion', [CompletionResultType]::ParameterValue, 'Generate shell completion')
                [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
                break
            }
            'uv;help;pip' {
                [CompletionResult]::new('compile', 'compile', [CompletionResultType]::ParameterValue, 'Compile a `requirements.in` file to a `requirements.txt` file')
                [CompletionResult]::new('sync', 'sync', [CompletionResultType]::ParameterValue, 'Sync dependencies from a `requirements.txt` file')
                [CompletionResult]::new('install', 'install', [CompletionResultType]::ParameterValue, 'Install packages into the current environment')
                [CompletionResult]::new('uninstall', 'uninstall', [CompletionResultType]::ParameterValue, 'Uninstall packages from the current environment')
                [CompletionResult]::new('freeze', 'freeze', [CompletionResultType]::ParameterValue, 'Enumerate the installed packages in the current environment')
                [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'Enumerate the installed packages in the current environment')
                [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Show information about one or more installed packages')
                [CompletionResult]::new('check', 'check', [CompletionResultType]::ParameterValue, 'Verify installed packages have compatible dependencies')
                break
            }
            'uv;help;pip;compile' {
                break
            }
            'uv;help;pip;sync' {
                break
            }
            'uv;help;pip;install' {
                break
            }
            'uv;help;pip;uninstall' {
                break
            }
            'uv;help;pip;freeze' {
                break
            }
            'uv;help;pip;list' {
                break
            }
            'uv;help;pip;show' {
                break
            }
            'uv;help;pip;check' {
                break
            }
            'uv;help;venv' {
                break
            }
            'uv;help;cache' {
                [CompletionResult]::new('clean', 'clean', [CompletionResultType]::ParameterValue, 'Clear the cache, removing all entries or those linked to specific packages')
                [CompletionResult]::new('prune', 'prune', [CompletionResultType]::ParameterValue, 'Prune all unreachable objects from the cache')
                [CompletionResult]::new('dir', 'dir', [CompletionResultType]::ParameterValue, 'Show the cache directory')
                break
            }
            'uv;help;cache;clean' {
                break
            }
            'uv;help;cache;prune' {
                break
            }
            'uv;help;cache;dir' {
                break
            }
            'uv;help;self' {
                [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Update `uv` to the latest version')
                break
            }
            'uv;help;self;update' {
                break
            }
            'uv;help;clean' {
                break
            }
            'uv;help;run' {
                break
            }
            'uv;help;version' {
                break
            }
            'uv;help;generate-shell-completion' {
                break
            }
            'uv;help;help' {
                break
            }
        })

    $completions.Where{ $_.CompletionText -like "$wordToComplete*" } |
    Sort-Object -Property ListItemText
}
