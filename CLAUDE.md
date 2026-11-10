# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ConnectWiseControlAPI is a PowerShell module wrapping the ConnectWise Control (formerly ScreenConnect) web API. It targets PowerShell 3.0+ and is published to the PowerShell Gallery. Used in production by MSPs for remote session management automation.

- **Repository**: https://github.com/christaylorcodes/ConnectWiseControlAPI
- **Version**: tracked in `ConnectWiseControlAPI/ConnectWiseControlAPI.psd1` (see `CHANGELOG.md`)
- **License**: MIT
- **Auth requirement**: HTTPS + either a non-MFA account with Basic auth (`Connect-CWC -Credentials`) or the RESTful API Manager extension secret (`Connect-CWC -ApiSecret`, subset of functions; `Invoke-CWCWebRequest` enforces which endpoints each mode may call)

## Development Commands

```powershell
# Import the module locally for development/testing
Import-Module ./ConnectWiseControlAPI/ConnectWiseControlAPI.psd1 -Force

# Run all Pester tests
Invoke-Pester -Path ./Tests/

# Run tests by tag
Invoke-Pester -Path ./Tests/ -Tag 'Authentication'

# Validate the module manifest
Test-ModuleManifest ./ConnectWiseControlAPI/ConnectWiseControlAPI.psd1

# Regenerate markdown docs (requires PlatyPS module)
Import-Module ./ConnectWiseControlAPI/ConnectWiseControlAPI.psd1 -Force
New-MarkdownHelp -Module ConnectWiseControlAPI -OutputFolder ./Docs -Force
```

CI runs on AppVeyor via `Tests/appveyor.pester.ps1`. Unit tests mock all HTTP calls; run them on PS 7 and
Windows PowerShell 5.1. `Tests/Live/Invoke-CWCLiveSmokeTest.ps1` checks behaviour against a real server.

All API calls go through `Private/Invoke-CWCServiceMethod.ps1` (endpoint, JSON arguments, `-Idempotent`
retry opt-in, `-Sensitive` log redaction), which calls `Private/Invoke-CWCWebRequest.ps1` (transport).
Session event type numbers live in `$script:CWCSessionEventType` (`.psm1`).

## Architecture

### Module Loading (`ConnectWiseControlAPI.psm1`)

The `.psm1` auto-discovers and dot-sources all `.ps1` files under `Public/` and `Private/` recursively. Only `Public/` function basenames are exported via `Export-ModuleMember`. Adding a new `.ps1` file in the right directory is enough for the module to pick it up — but you must also add the function name to `FunctionsToExport` in the `.psd1` manifest.

The module sets `[Net.ServicePointManager]::SecurityProtocol` to enable TLS and defines `$script:InternalUserSource = 'InternalMembershipProvider'` used by SecurityService functions.

### Authentication Flow (`Connect-CWC`)

1. Takes `$Server` (hostname) and `$Credentials` (PSCredential)
2. Builds Basic auth header from credentials
3. Fetches the server's front page to extract an **anti-forgery token** via regex
4. Stores connection state in `$script:CWCServerConnection` (hashtable with `Server` and `Headers` including auth + anti-forgery + cookies)
5. Validates by calling `Get-CWCSessionGroup`

All public functions check `$script:CWCServerConnection` before making API calls.

### Centralized API Requests (`Private/Invoke-CWCWebRequest.ps1`)

Every API call goes through `Invoke-CWCWebRequest`, which:
- Uses `Invoke-WebRequest -UseBasicParsing` for PS version compatibility
- Handles cookie tracking (`Set-Cookie` header updates)
- Implements **retry with exponential backoff** (up to 5 retries on HTTP 500)
- Has version-aware error handling (PS 5 vs PS 6+ handle `.Exception.Response` differently)
- Returns deserialized JSON or saves to file via `-OutFile`

### Public Function Organization

Functions are organized by Control API service endpoint:

| Directory | Service | Key Functions |
|-----------|---------|---------------|
| `Authentication/` | Auth | `Connect-CWC` |
| `PageService/` | Sessions | `Get-CWCSession`, `Invoke-CWCCommand`, `Remove-CWCSession`, etc. |
| `SecurityService/` | Users | `New-CWCUser`, `Update-CWCUser`, `Remove-CWCUser` |
| `AuditService/` | Auditing | `Get-CWCAuditLog`, `Get-CWCAuditInfo` |
| `SessionGroupService/` | Groups | `Get-CWCSessionGroup` |
| `Extensions/` | Add-ons | Remote Workforce, Launcher URL functions |
| `Helpers/` | Utilities | `New-CWCMFA` (MFA token/QR generation) |

### Adding a New Function

1. Create `.ps1` in the appropriate `Public/[Service]/` directory
2. Follow the `Verb-CWCNoun` naming convention (PowerShell approved verbs, `CWC` prefix)
3. Check `$script:CWCServerConnection` at the start; use `Invoke-CWCWebRequest` for API calls
4. Add function name to `FunctionsToExport` array in the `.psd1` manifest
5. Use existing functions as templates — `Get-CWCSession.ps1` is a good reference for the pattern

### URL Construction

API endpoints follow the pattern: `$script:CWCServerConnection.Server/Services/{ServiceName}.ashx/{MethodName}`

The `Private/Join-Url` helper joins URL path segments.

## Code Conventions

- All public functions require comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES` with version/author/date, `.LINK`)
- Use `[CmdletBinding()]` and parameter validation attributes (`[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, etc.)
- Return objects, not formatted output
- Use `Write-Error` for non-terminating errors, `throw` for validation failures
- Destructive operations should support `-WhatIf` and `-Confirm` via `[CmdletBinding(SupportsShouldProcess)]`
- Prefer verbose, self-documenting code over abbreviated or clever solutions

## User Context

Author preferences and coding standards are maintained at `C:\_Code\CHRIS\CHRIS.md` and `C:\_Code\CHRIS\config\coding_standards.md`. Reference these for style decisions.
