# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

PowerShell module wrapping the ConnectWise Control (ScreenConnect) web API; published to the PowerShell Gallery and used by MSPs. Version lives in `ConnectWiseControlAPI/ConnectWiseControlAPI.psd1` (history in `CHANGELOG.md`). Three auth modes via `Connect-CWC` (stored as `AuthType`):

- `-Credentials` (`Credentials`): Basic auth, non-MFA account. Reaches the built-in `Services/*.ashx` and extensions.
- `-Credentials` plus `-Mfa`, `-OneTimeCode` or `-TotpSecret` (`Mfa`): `Private/Invoke-CWCMfaLogin.ps1` signs in with `AuthenticationService.TryLogin` and the connection uses the `.ASPXAUTH` cookie, with no Authorization header and no stored password. Reaches the same endpoints as `Credentials`. The login expires; a cache hit is re-checked with `GetEligibleHosts`.
- `-ApiSecret`: RESTful API Manager extension secret. Reaches only that extension's methods: `Public/RestApi/` functions plus the dual-mode ones (`Get-CWCSessionDetail`, `Update-CWCSessionName`, `Invoke-CWCCommand`), which branch on `Test-CWCApiSecretConnection`.

## Commands

```powershell
Import-Module ./ConnectWiseControlAPI/ConnectWiseControlAPI.psd1 -Force
Invoke-Pester -Path ./Tests/                                           # all tests (HTTP is mocked)
Invoke-Pester -Path ./Tests/ConnectWiseControlAPI.Private.Tests.ps1    # one file
Test-ModuleManifest ./ConnectWiseControlAPI/ConnectWiseControlAPI.psd1
New-MarkdownHelp -Module ConnectWiseControlAPI -OutputFolder ./Docs -Force   # PlatyPS, after Import-Module
```

Run unit tests on both PS 7 and Windows PowerShell 5.1. `Tests/ConnectWiseControlAPI.Live.Tests.ps1` skips unless `$env:CWC_SERVER`, `CWC_USER` and `CWC_PASSWORD` are set. `Tests/Live/Invoke-CWCLiveSmokeTest.ps1` checks behaviour against a real server (read-only unless `-AllowWrites`). CI is AppVeyor (`Tests/appveyor.pester.ps1`).

## Architecture

- **Loading**: the `.psm1` dot-sources every `.ps1` under `Public/` and `Private/` and exports the `Public/` basenames, but a new function must also be added to `FunctionsToExport` in the `.psd1`. The `.psm1` also holds the shared constants: `$script:CWCSessionType`, `$script:CWCSessionEventType` (live-verified numbers) and the Remote Workforce and RESTful API Manager extension IDs.
- **Requests**: every public function calls `Private/Invoke-CWCServiceMethod.ps1`. It builds the endpoint (`-Service` → `Services/<Service>.ashx/<Method>`, `-RestApi` / `-ExtensionID` → `App_Extensions/<id>/Service.ashx/<Method>`) and sends the arguments as a **positional JSON array** matching the server method's signature. `-Idempotent` turns on retry for HTTP 500 (3 retries, waiting 2/4/8 s; never for permission errors; otherwise none, so commands/notes/deletes never repeat). Session events go through `Private/Add-CWCSessionEvent.ps1`. Transport errors carry an ErrorId (`CWC.NotConnected`, `CWC.AuthModeMismatch`, `CWC.Http<status>`, `CWC.NoResponse`). `-Sensitive` redacts the body from verbose and debug output.
- **Transport**: `Private/Invoke-CWCWebRequest.ps1` checks that a connection exists, **blocks calls that don't match the auth mode** (API-secret connections may only reach the RESTful API Manager), adds auth headers, handles PS 5 vs 6+ error shapes, and returns parsed JSON.
- **Connection state**: `$script:CWCServerConnection` holds `Server`, `AuthType`, and `Headers`. Credentials mode adds a `WebSession` (cookies) and an anti-forgery token taken from the front page. ApiSecret mode sends `CTRLAuthHeader`. Connect-CWC validates the login with a test call and restores the previous connection if that call fails.

## Adding a function

1. Add `Public/<Service>/Verb-CWCNoun.ps1` (approved verb, `CWC` prefix). Use `Get-CWCSession.ps1` as the template.
2. Call `Invoke-CWCServiceMethod`. Check the method name and argument order against the server source (see memory). Pass `-Idempotent` only for reads and "set to value" updates.
3. Add the name to `FunctionsToExport` in the `.psd1`.
4. Add mocked Pester tests to `Tests/ConnectWiseControlAPI.Public.Tests.ps1`.

## Conventions

- Destructive functions use `[CmdletBinding(SupportsShouldProcess)]`. Never pass the request body (it may hold a password) as the `ShouldProcess` target.
- Report errors with `Write-Error` (non-terminating) and let callers decide. Return objects, not formatted output.
- Public functions need comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`). Only some functions have it so far; add it to any function you touch.
- Code must run on Windows PowerShell 5.1 (e.g. no `??`, no ternary).
