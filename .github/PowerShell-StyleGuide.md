# PowerShell Style Guide

> **ConnectWiseControlAPI exception:** this module runs from RMM agents, so it targets PowerShell 3.0+
> and must work on Windows PowerShell 5.1 (no ternary, `??`, `&&`/`||` or other 7-only syntax). Only the
> build and test tooling needs PowerShell 7. This repo uses the Sampler/ModuleBuilder build and `source/`
> layout, but **not** Pester 6, the Sampler test task or PlatyPS 1.x / `docs/help` (it uses Pester 5.7 through
> `Tests/test-local.ps1` and `Build/Update-Help.ps1`), and test runners must not set a global
> `$ErrorActionPreference = 'Stop'` (it breaks the module's error-path tests). Where this guide disagrees, follow
> [AGENTS.md](../AGENTS.md); everything else applies as written.

This is the authoritative style guide for all PowerShell projects. It applies to both formal modules (built with Sampler/ModuleBuilder, using InvokeBuild as the task runner) and standalone script collections. All projects should reference this file rather than duplicating conventions.

## Language Targets

| Context | Version | Rationale |
|---|---|---|
| PowerShell modules | 7.6+ | Current LTS (7.4 LTS and 7.5 reached end of support 2026-11-10) |
| Scripts deployed to managed endpoints | 5.1+ | Windows ships with 5.1; can't guarantee 7.x on all endpoints |
| CI/CD pipelines | 7.6+ | Controlled environment, use latest stable |

When writing a module, do not add 5.1 compatibility unless the module explicitly targets Windows PowerShell. When writing endpoint scripts, avoid 7.x-only syntax (ternary `?:`, null-coalescing `??`, pipeline chain `&&`/`||`).

## Formatting Rules

Formatting is enforced by PSScriptAnalyzer. The settings file (`.PSScriptAnalyzerSettings.psd1`) is the source of truth. Key decisions:

- **4-space indentation**, spaces only, no tabs
- **120-character max line length**
- **Open braces on same line**: `if ($true) {`
- **Single quotes for constants**, double quotes only when interpolation is needed
- **Align hashtable assignment operators** for readability
- **UTF-8 with BOM** for `.ps1`/`.psm1`/`.psd1` files, CRLF line endings
- **No trailing whitespace** except in Markdown (where trailing spaces create line breaks)

### Why Single Quotes

Double-quoted strings invoke the parser's variable expansion. Using them for constants creates a subtle injection surface and makes intent ambiguous:

```powershell
# Correct
$path = 'C:\Windows\System32'
$message = "Processing $itemCount items"

# Wrong
$path = "C:\Windows\System32"     # No interpolation needed
$message = 'Processing ' + $count # Awkward concatenation when interpolation is cleaner
```

## Naming Conventions

### Functions

- Use **approved verbs** only (`Get-Verb` for the full list)
- **PascalCase** with `Verb-Noun` format: `Get-BackupStatus`, `New-ClientReport`
- **Singular nouns**: `Get-User` not `Get-Users` (the function can return multiple objects)
- Private helper functions still use `Verb-Noun` but are not exported

### Parameters

- **PascalCase**: `$ComputerName`, `$OutputPath`
- **No abbreviations** unless universally understood: `$Id` is fine, `$Comp` is not
- **Use standard parameter names** when applicable: `$ComputerName` not `$Server`, `$Path` not `$FilePath`, `$Credential` not `$Creds`

### Variables

- **PascalCase** for all variables: `$ResultList`, `$ErrorCount`
- **Descriptive names**: `$activeClients` not `$ac`
- **Collections should indicate plurality**: `$tickets`, `$computerNames`

### Files

- **One function per file** in modules, filename matches function name: `Get-BackupStatus.ps1`
- **Hyphen-separated** for standalone scripts: `Gather-BrightGauge-Data.ps1`
- **Vendor prefixes** for vendor-specific scripts: `CWM-CloseStaleTickets.ps1`

## Function Structure

### Module Functions (Public)

Use `begin`/`process`/`end` blocks when the function accepts pipeline input. Skip them for functions that don't:

```powershell
# Pipeline-capable function: use begin/process/end
function Get-ServiceStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ComputerName
    )

    begin {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        # Per-item logic
    }

    end {
        return $results
    }
}
```

```powershell
# Non-pipeline function: flat structure is fine
function Connect-MyService {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [PSCredential]$Credential
    )

    Write-Verbose -Message "Connecting to service"
    # Connection logic
}
```

### Standalone Scripts

Use the region-based structure with declarations, initializations, functions, and execution:

```powershell
[CmdletBinding()]
param()

#region [Declarations]
$ErrorActionPreference = 'Stop'
[version]$ScriptVersion = '1.0.0'
#endregion

#region [Initializations]
[System.Net.ServicePointManager]::SecurityProtocol = 3072
# Module loading, logging setup
#endregion

#region [Functions]
# Local function definitions
#endregion

#region [Execution]
try {
    # Main logic
} catch {
    # Error handling
}
finally {
    # Cleanup
}
#endregion
```

## Comment-Based Help

Required on all exported functions. Place the help block **inside** the function, at the top of the body before `[CmdletBinding()]` (this is what `Templates/Function.ps1` and `Scripts/New-Function.ps1` generate):

```powershell
function Get-BackupStatus {
    <#
    .SYNOPSIS
        One line. What it does, not how.

    .DESCRIPTION
        More detail. When you'd use it, what it connects to, important caveats.

    .PARAMETER ComputerName
        What it accepts and any constraints.

    .INPUTS
        System.String. The .NET type accepted from the pipeline.

    .OUTPUTS
        PSCustomObject. What the function returns.

    .EXAMPLE
        Get-BackupStatus -ComputerName 'SERVER01'

        Returns backup status for SERVER01.

    .NOTES
        Version:        1.0.0
        Author:         Your Name
        Creation Date:  YYYY-MM-DD
        Purpose/Change: Initial development
    #>
    [CmdletBinding()]
    param(...)
}
```

For standalone scripts, the help block goes at the top of the file before `[CmdletBinding()]`.

Private functions: `.SYNOPSIS`, `.PARAMETER`, and one `.EXAMPLE` are sufficient. Skip `.INPUTS`/`.OUTPUTS`/`.LINK`.

### Documentation Generation (PlatyPS)

Comment-based help is the **source of truth** for all documentation. `Get-Help` reads it directly from the built module, so no MAML/XML help is generated. For reference docs (GitHub, a docs site), the build generates markdown from it with Microsoft.PowerShell.PlatyPS 1.x:

```powershell
./build.ps1 -Tasks docs  # Build, then regenerate docs/help/<ModuleName>/*.md from comment-based help
```

**Flow:** `.ps1` comment-based help → built module → PlatyPS (`Scripts/Update-MarkdownHelp.ps1`) → `docs/help/<ModuleName>/`. The folder is regenerated from scratch on every run and each file is validated with `Test-MarkdownCommandHelp`. Do not hand-edit the generated markdown: update the comment-based help and regenerate. The task lists any remaining `{{ ... }}` placeholders, which point at gaps in your comment-based help.

### Known Parser Pitfall: Dot at Start of Line

PowerShell's comment-based help parser treats any line beginning with a dot followed by a word (`.SYNOPSIS`, `.PARAMETER`, etc.) as a **help keyword**. This means terms like `.NET`, `.config`, or `.exe` at the start of a line — even a continuation line — will silently break the entire help block. `Get-Help` will return empty descriptions for all parameters with no error or warning.

```powershell
# BAD — .NET starts a line, parsed as unknown keyword, breaks all help
<#
.DESCRIPTION
    The function handles prerequisite checks including
    .NET Framework 3.5 validation and MSI integrity.
#>

# GOOD — .NET appears mid-line
<#
.DESCRIPTION
    The function handles prerequisite checks including validation
    of .NET Framework 3.5 and MSI integrity.
#>
```

This applies to any dot-word combination: `.NET`, `.config`, `.exe`, `.dll`, `.json`, etc. Always ensure these terms appear in the middle of a line, never at the start (after indentation).

## Error Handling

### Standard Pattern

```powershell
$ErrorActionPreference = 'Stop'

try {
    $result = Get-Something -Id $Id
} catch [System.Net.WebException] {
    # Typed catch for expected failures: add context, keep the original as InnerException
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Network error retrieving ID $Id", $_.Exception),
        'GetSomethingNetworkError',
        [System.Management.Automation.ErrorCategory]::ConnectionError,
        $Id
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
} catch {
    # General catch for unexpected failures: re-throw attributed to this function
    $PSCmdlet.ThrowTerminatingError($_)
}
```

### Rules

- Always set `$ErrorActionPreference = 'Stop'` at the script level, or use `-ErrorAction Stop` on individual cmdlets
- **Catch specific exception types** when you can handle them differently
- **Include context** in error messages: what you were trying to do, which item failed
- **Re-throw** (`throw` with no arguments) unless you genuinely handle the error
- **Never use empty catch blocks** (PSSA enforces this)
- In advanced functions, propagate with `$PSCmdlet.ThrowTerminatingError()` so the error is attributed to the function, not a line inside it
- **Never** write `Write-Error -Message '...' -ErrorRecord $_`: `-Message` and `-ErrorRecord` are in different parameter sets, so the call fails to bind and hides the real error

### What NOT To Do

```powershell
# Don't silently swallow errors
catch { }

# Don't lose the original error record
catch { Write-Error $_.Exception.Message }  # Loses stack trace

# Don't use return codes for error signaling in modules
catch { return -1 }
```

## Logging

### In Modules

Use `Write-Verbose` and `Write-Debug`. Never use `Write-Host` in module code. The caller controls verbosity via `-Verbose` and `-Debug` switches.

```powershell
Write-Verbose -Message "Processing item: $ItemName"
Write-Debug -Message "Raw API response: $($response | ConvertTo-Json -Depth 3)"
```

### In Standalone Scripts

**Prefer Windows Event Log** for most scripts. It is built into the OS, requires zero module dependencies, integrates with existing monitoring tools (Event Viewer, SIEM, RMM platforms), and survives script crashes (writes are immediate, no flush needed).

#### Windows Event Log (Default -- Preferred)

Use for any script that runs on Windows endpoints, scheduled tasks, or RMM-deployed automation:

```powershell
#region [Initializations]
$LogSource = 'MyCompany-Automation'
$LogName   = 'Application'

# Register the source if it doesn't exist (requires elevation, run once per machine)
if (-not [System.Diagnostics.EventLog]::SourceExists($LogSource)) {
    New-EventLog -LogName $LogName -Source $LogSource
}
#endregion

# Usage
Write-EventLog -LogName $LogName -Source $LogSource -EntryType Information -EventId 1000 -Message 'Script started'
Write-EventLog -LogName $LogName -Source $LogSource -EntryType Warning     -EventId 2000 -Message 'Retry attempt 2 of 3'
Write-EventLog -LogName $LogName -Source $LogSource -EntryType Error       -EventId 3000 -Message "Fatal: $($_.Exception.Message)"
```

**Event ID conventions:**

- `1000-1999` -- Informational (script start, milestones, completion)
- `2000-2999` -- Warnings (retries, degraded state, skipped items)
- `3000-3999` -- Errors (failures, exceptions, abort conditions)

**Benefits over file-based logging:**

- Zero dependencies (no modules to install or update)
- Survives script crashes (no buffered writes to flush)
- Queryable by monitoring tools, SIEM, and RMM platforms out of the box
- Built-in rotation and retention managed by Windows
- Centralized when forwarded via Windows Event Forwarding or log collectors

#### PSFramework (When You Need More)

Use PSFramework when you specifically need structured logging with tags/data objects, CMTrace-formatted files for SCCM-style log viewers, multi-provider output (simultaneous file + console + Teams), or cross-platform support on PS 7+ Linux hosts:

```powershell
$Modules = @('PSFramework')
# [Module auto-installation]

$LogPath = "$env:windir\LTSvc\logs"
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$LogFile = Join-Path $LogPath "$ScriptName-%Date%.log"

Set-PSFLoggingProvider -Name logfile -InstanceName $ScriptName -FilePath $LogFile -Enabled $true -FileType CMTrace
Set-PSFLoggingProvider -Name console -Enabled $true

# Usage
Write-PSFMessage -Level Host -Message 'Starting processing'
Write-PSFMessage -Level Warning -Message 'Retrying' -Tag 'API', 'Retry' -Data @{ Attempt = 2 }
Write-PSFMessage -Level Error -Message 'Fatal error' -ErrorRecord $_

# ALWAYS call before script exit
Wait-PSFMessage
```

#### Legacy Patterns

`Logging` module: maintain in existing scripts, do not introduce into new code. Migrate to Event Log or PSFramework when refactoring.

## Preferred Modules and Approaches

| Need | Use | Don't Use |
|---|---|---|
| Logging (scripts) | Windows Event Log (default), `PSFramework` (advanced) | `Logging` module (unmaintained since 2022) |
| Azure AD / Entra | `Microsoft.Graph` | `MSOnline`, `AzureAD` (deprecated) |
| Exchange Online | `ExchangeOnlineManagement` v3+ | Basic auth / remote PSSession |
| Credential storage | Azure Key Vault, `SecretManagement` | Hardcoded strings, plain-text files |
| REST API calls | `Invoke-RestMethod` | `Invoke-WebRequest` (unless you need response headers) |
| JSON handling | `ConvertTo-Json`/`ConvertFrom-Json` | Manual string building |
| Collections (building lists) | `[System.Collections.Generic.List[T]]` | `+=` on arrays (O(n) reallocation) |
| Null checking (PS 7+) | `$x ?? 'default'` | `if ($null -eq $x) { 'default' }` |
| String building | `-f` operator or interpolation | Repeated `+` concatenation |
| File paths | `Join-Path` | String concatenation with `\` |

## Security Requirements

- **TLS 1.2 minimum**: `[System.Net.ServicePointManager]::SecurityProtocol = 3072`
- **Never hardcode credentials** or API keys in source files
- **Use `[PSCredential]`** for credential parameters, never separate username/password parameters
- **Validate all external input** (parameters, API responses, file content)
- **Avoid `Invoke-Expression`** (PSSA enforces this) -- if loading remote scripts is unavoidable, pin to a specific commit hash
- **SSL certificate bypass** (`TrustAllCertsPolicy`) is only acceptable for internal tooling against known endpoints, never in production/public code

## Output Conventions

- Return **typed objects** (`[PSCustomObject]` with named properties), not formatted strings
- Use `[OutputType()]` attribute on all functions
- Add `PSTypeName` to custom objects for format/type system integration:
  ```powershell
  [PSCustomObject]@{
      PSTypeName = 'ModuleName.BackupStatus'
      Name       = $job.Name
      Status     = $job.LastResult
  }
  ```
- For progress on long operations, use `Write-Progress` (scripts) or `Write-Verbose` (modules)
- Functions should output objects to the pipeline, not store them and return at the end, unless ordering/aggregation requires it

## Testing Standards

Tests are not optional. They are how code proves it works, how regressions get caught, and how AI agents get the feedback they need to iterate without human intervention. Code that cannot be tested cannot be trusted.

### Requirements

- **Every exported function must have a matching test file**
- **Pester 6** with configuration-based invocation
- **PSScriptAnalyzer** runs as part of every test cycle (`-IncludeAnalyzer`), zero errors required
- Test structure per function: `Parameter Validation` > `Functionality` > `Error Handling` > `Edge Cases`

### Design for Testability

Write code that is easy to test. If something is hard to test, that is a design problem, not a testing problem.

**Keep functions small and single-purpose.** A function that connects to an API, transforms data, and writes output is three functions. Split them so each can be tested in isolation:

```powershell
# Hard to test: does everything, requires live API
function Sync-UserData {
    $users = Invoke-RestMethod -Uri $apiUrl        # Network call
    $mapped = $users | ForEach-Object { ... }       # Transformation
    $mapped | Export-Csv -Path $outputPath           # File I/O
}

# Easy to test: each piece is independently verifiable
function Get-RemoteUserData {        # Mock the API call
    [CmdletBinding()]
    param([string]$ApiUrl)
    return Invoke-RestMethod -Uri $ApiUrl
}

function ConvertTo-UserRecord {      # Pure transformation, no mocking needed
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][object]$InputObject)
    process {
        [PSCustomObject]@{
            Name  = $InputObject.displayName
            Email = $InputObject.mail
        }
    }
}

function Export-UserReport {         # Mock the file system
    [CmdletBinding()]
    param([object[]]$UserData, [string]$Path)
    $UserData | Export-Csv -Path $Path -NoTypeInformation
}
```

**Pass dependencies as parameters, not hardcoded values.** This makes mocking straightforward:

```powershell
# Hard to test: buried dependency
function Get-BackupStatus {
    $vault = Connect-AzKeyVault -VaultName 'production-vault'  # Can't test without real vault
    ...
}

# Easy to test: inject the dependency
function Get-BackupStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VaultName
    )
    $vault = Connect-AzKeyVault -VaultName $VaultName  # Mock Connect-AzKeyVault in tests
    ...
}
```

**Return objects, not formatted strings.** Objects can be asserted against; strings require fragile regex matching:

```powershell
# Hard to test: "Backup OK - 3 jobs succeeded"... now parse that
function Get-BackupSummary { return "Backup $status - $count jobs $result" }

# Easy to test: $result.Status | Should -Be 'OK'
function Get-BackupSummary {
    [OutputType([PSCustomObject])]
    param()
    return [PSCustomObject]@{
        Status    = $status
        JobCount  = $count
        JobResult = $result
    }
}
```

**Avoid module-level side effects.** If importing your module triggers API calls, file reads, or connection attempts, tests cannot run in isolation. Defer initialization to explicit function calls.

### What Good Tests Look Like

Tests should answer four questions:

1. **Do the parameters work?** Mandatory parameters reject nulls, validation attributes enforce constraints, pipeline input is accepted where declared.

2. **Does the happy path produce correct output?** Given known inputs, the output has the right type, the right properties, and the right values.

3. **Do errors behave correctly?** Invalid inputs throw. API failures propagate with context. The function does not silently return `$null` when it should throw.

4. **Do edge cases survive?** Empty collections, special characters, very long strings, `$null` in unexpected places.

```powershell
Describe 'Get-BackupStatus' {
    Context 'Parameter Validation' {
        It 'Should require ComputerName' {
            (Get-Command Get-BackupStatus).Parameters['ComputerName'].Attributes.Mandatory |
                Should -Be $true
        }

        It 'Should reject empty ComputerName' {
            { Get-BackupStatus -ComputerName '' } | Should -Throw
        }
    }

    Context 'Functionality' {
        BeforeAll {
            Mock Invoke-RestMethod -ModuleName 'MyModule' -MockWith {
                return @{ status = 'Healthy'; lastBackup = '2025-01-15' }
            }
        }

        It 'Should return a PSCustomObject with expected properties' {
            $result = Get-BackupStatus -ComputerName 'SERVER01'
            $result | Should -BeOfType [PSCustomObject]
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.PSObject.Properties.Name | Should -Contain 'LastBackup'
        }

        It 'Should call the API exactly once per computer' {
            Get-BackupStatus -ComputerName 'SERVER01'
            Should -Invoke Invoke-RestMethod -ModuleName 'MyModule' -Times 1 -Exactly
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            Mock Invoke-RestMethod -ModuleName 'MyModule' -MockWith {
                throw [System.Net.WebException]::new('Connection refused')
            }
        }

        It 'Should throw when the API is unreachable' {
            { Get-BackupStatus -ComputerName 'SERVER01' } | Should -Throw '*Connection refused*'
        }
    }

    Context 'Edge Cases' {
        It 'Should handle multiple computers via pipeline' {
            Mock Invoke-RestMethod -ModuleName 'MyModule' -MockWith {
                return @{ status = 'Healthy' }
            }
            $results = @('SRV01', 'SRV02', 'SRV03') | Get-BackupStatus
            $results.Count | Should -Be 3
        }
    }
}
```

### Mock External Dependencies

Never let tests hit real APIs, databases, or file systems. Mock everything external:

```powershell
# Mock API calls
Mock Invoke-RestMethod -ModuleName 'MyModule' -MockWith { return @{ data = 'test' } }

# Mock file system operations
Mock Test-Path -ModuleName 'MyModule' -MockWith { return $true }
Mock Export-Csv -ModuleName 'MyModule'

# Mock credential retrieval
Mock Get-AzKeyVaultSecret -ModuleName 'MyModule' -MockWith {
    return [PSCustomObject]@{
        SecretValue = (ConvertTo-SecureString 'mock' -AsPlainText -Force)
    }
}

# Verify mocks were called with expected arguments
Should -Invoke Invoke-RestMethod -ModuleName 'MyModule' -Times 1 -ParameterFilter {
    $Uri -like '*/api/backup*'
}
```

Always use `-ModuleName` on every `Mock` and `Should -Invoke` call. Without it, mocks target the test scope instead of the module scope, and the real cmdlet runs inside the function.

### The AI Agent Feedback Loop

AI agents depend on test output to know whether their code works. Design tests to give clear, actionable signals:

- **Structured output**: Use `-OutputFormat Structured` with `Invoke-QuickTest.ps1` so agents can parse JSON results programmatically instead of scraping console text
- **Specific assertions**: `$result.Name | Should -Be 'Expected'` tells the agent exactly what failed. `$result | Should -Not -BeNullOrEmpty` tells it almost nothing
- **Descriptive It blocks**: The test name IS the error message. `'Should return Healthy when all jobs pass'` is actionable. `'Should work'` is not
- **Fast feedback**: Quick-test a single function during development (`Invoke-QuickTest.ps1`), full suite before commit (`test-local.ps1`). Do not make agents wait for the full suite on every iteration
- **No test should depend on another test**: Tests must pass when run individually and in any order. Use `BeforeEach` for per-test setup, `BeforeAll` for shared read-only context

## Things to Avoid

- `Write-Host` in module code (breaks automation, untestable)
- Aliases in scripts and modules (`%` -> `ForEach-Object`, `?` -> `Where-Object`, `iex` -> `Invoke-Expression`)
- Positional parameters in calls longer than one argument
- `[void]` casting to suppress output -- use `$null =` or pipe to `Out-Null` for clarity
- `Add-Type` with inline C# unless genuinely necessary (prefer .NET methods directly)
- Global variables (`$global:`) -- use `$script:` scope or pass as parameters
- Magic numbers -- assign to named constants: `$maxRetryCount = 3` not bare `3`
- Backtick line continuation -- use splatting or natural line breaks (after `|`, `,`, `(`, `{`)
