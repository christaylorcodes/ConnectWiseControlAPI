# AGENTS.md

Single source of truth for AI agents (Claude Code, Copilot, others) working in this repository. Structure follows
the [GitHub-Template](https://github.com/christaylorcodes/GitHub-Template); deliberate differences are listed under
[Template differences](#template-differences).

## Project Overview

PowerShell module wrapping the ConnectWise Control (ScreenConnect) web API; published to the PowerShell Gallery and
used by MSPs. Source lives in `source/` (Sampler layout); `./build.ps1` builds the publishable module into
`output/<ModuleName>/<version>/`. Version: `ModuleVersion` in `source/ConnectWiseControlAPI.psd1` (history in
`CHANGELOG.md`).
Three auth modes via `Connect-CWC` (stored as `AuthType`):

- `-Credentials` (`Credentials`): Basic auth, non-MFA account. Reaches the built-in `Services/*.ashx` and extensions.
- `-Credentials` plus `-Mfa`, `-OneTimeCode` or `-TotpSecret` (`Mfa`): `Private/Invoke-CWCMfaLogin.ps1` signs in with
  `AuthenticationService.TryLogin` and the connection uses the `.ASPXAUTH` cookie, with no Authorization header and no
  stored password. Reaches the same endpoints as `Credentials`. The login expires; a cache hit is re-checked with
  `GetEligibleHosts`.
- `-ApiSecret`: RESTful API Manager extension secret. Reaches only that extension's methods: `Public/RestApi/`
  functions plus the dual-mode ones (`Get-CWCSessionDetail`, `Update-CWCSessionName`, `Invoke-CWCCommand`), which
  branch on `Test-CWCApiSecretConnection`.

## Quick Start

```powershell
# Development: import straight from source/
Import-Module ./source/ConnectWiseControlAPI.psd1 -Force

# Build the publishable module (first run resolves build dependencies into output/RequiredModules)
./build.ps1 -ResolveDependency -Tasks build

# Everything CI runs: build, PSScriptAnalyzer, Test-ModuleManifest, Pester against the BUILT module on PS 7
# *and* Windows PowerShell 5.1, docs drift
./Tests/test-local.ps1

# One stage (Test uses the last build; add -TestSource to test source/ instead)
./Tests/test-local.ps1 -Stage Test
./Tests/test-local.ps1 -Stage Analyze, Manifest

# One test file against source/ (HTTP is mocked). Tests import $env:MODULE_TEST_PATH when set, else source/.
Invoke-Pester -Path ./Tests/ConnectWiseControlAPI.Private.Tests.ps1

# Regenerate Docs/, ConnectWiseControlAPI_Functions.md and the MAML help (never edit those by hand)
./Build/Update-Help.ps1
```

Tooling: PowerShell 7 for the build; Pester 5.7.1+, PSScriptAnalyzer, platyPS 0.14.x (`RequiredModules.psd1`).

`Tests/ConnectWiseControlAPI.Live.Tests.ps1` skips unless `$env:CWC_SERVER`, `CWC_USER` and `CWC_PASSWORD` are set.
`Tests/Live/Invoke-CWCLiveSmokeTest.ps1` checks behaviour against a real server (read-only unless `-AllowWrites`).

## CI/CD

`.github/workflows/ci.yml` runs on `windows-latest`. Each job calls one stage of `Tests/test-local.ps1`:

| Job | What it checks |
| --- | --- |
| Build module | `./build.ps1` (Sampler/ModuleBuilder); `Test-ModuleManifest` on source and built manifests |
| Pester (PowerShell 7) / Pester (Windows PowerShell 5.1) | Full Pester suite against the built module, both editions |
| PSScriptAnalyzer | Zero analyzer errors in `source/` |
| Docs drift | `Build/Update-Help.ps1` leaves no diff |

`.github/workflows/pr-validation.yml` warns when a PR doesn't update `CHANGELOG.md`. Publishing to the PowerShell
Gallery is manual and needs the owner's explicit go: build, then
`Publish-Module -Path output/<ModuleName>/<version> -NuGetApiKey <key>` (publish the built folder, not `source/`).

## Architecture

- **Loading**: `build.ps1` (ModuleBuilder) merges `source/prefix.ps1`, `Private/` and `Public/` into one `.psm1` and
  writes `FunctionsToExport` from the `Public/` file names (the source manifest says `'*'`). The source `.psm1` is only
  for development: it dot-sources the same files and is **not** used by the build, so module-level code belongs in
  `source/prefix.ps1`. That file holds the TLS setup and the shared constants: `$script:CWCSessionType`,
  `$script:CWCSessionEventType` (live-verified numbers) and the Remote Workforce and RESTful API Manager extension IDs.
- **Requests**: every public function calls `Private/Invoke-CWCServiceMethod.ps1`. It builds the endpoint
  (`-Service` → `Services/<Service>.ashx/<Method>`, `-RestApi` / `-ExtensionID` →
  `App_Extensions/<id>/Service.ashx/<Method>`) and sends the arguments as a **positional JSON array** matching the
  server method's signature. `-Idempotent` turns on retry for HTTP 500 (3 retries, waiting 2/4/8 s; never for
  permission errors; otherwise none, so commands/notes/deletes never repeat). Session events go through
  `Private/Add-CWCSessionEvent.ps1`. Transport errors carry an ErrorId (`CWC.NotConnected`, `CWC.AuthModeMismatch`,
  `CWC.Http<status>`, `CWC.NoResponse`). `-Sensitive` redacts the body from verbose and debug output.
- **Transport**: `Private/Invoke-CWCWebRequest.ps1` checks that a connection exists, **blocks calls that don't match
  the auth mode** (API-secret connections may only reach the RESTful API Manager), adds auth headers, handles PS 5
  vs 6+ error shapes, and returns parsed JSON.
- **Connection state**: `$script:CWCServerConnection` holds `Server`, `AuthType`, and `Headers`. Credentials mode
  adds a `WebSession` (cookies) and an anti-forgery token taken from the front page. ApiSecret mode sends
  `CTRLAuthHeader`. Connect-CWC validates the login with a test call and restores the previous connection if that
  call fails.

## Adding New Functions

1. Add `source/Public/<Service>/Verb-CWCNoun.ps1` (approved verb, `CWC` prefix). Use `Get-CWCSession.ps1` as the
   template. No manifest edit: the build exports every `Public/` file.
2. Call `Invoke-CWCServiceMethod`. Check the method name and argument order against the Control server's
   `Services/*.ashx` source. Pass `-Idempotent` only for reads and "set to value" updates.
3. Add mocked Pester tests to `Tests/ConnectWiseControlAPI.Public.Tests.ps1`.
4. Run `./Build/Update-Help.ps1` and commit the generated pages.

## Code Conventions

Full style guide: [.github/PowerShell-StyleGuide.md](.github/PowerShell-StyleGuide.md) (read its version note
first). It lives under `.github/` rather than the template's `docs/` because Windows treats `docs/` and the
platyPS `Docs/` folder as the same directory, and `Build/Update-Help.ps1` would process it as a command page.
Enforced by `.PSScriptAnalyzerSettings.psd1` and `.editorconfig`:

- **Code must run on PowerShell 3.0+ / Windows PowerShell 5.1**: no `??`, ternary, `&&`/`||`, or other 7-only syntax.
- 4-space indentation, max 120 characters per line, open brace on the same line, cuddled `} else {` / `} catch {`.
- Single quotes for constants, double quotes only for interpolation. Approved verbs only.
- Public functions need comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`). Not every
  function has it yet; add it to any function you touch.
- Destructive functions use `[CmdletBinding(SupportsShouldProcess)]`. Never pass the request body (it may hold a
  password) as the `ShouldProcess` target.
- Report errors with `Write-Error` (non-terminating) and let callers decide. Return objects, not formatted output.
- PowerShell files: UTF-8 with BOM, CRLF line endings.
- `.gitignore` secret patterns are deliberately narrow (`*secret*` once hid `Test-CWCApiSecretConnection.ps1`);
  a module test fails if any file under `source/`, `Tests/`, `Docs/`, `Build/`, `.build/` or `Examples/` is
  ignored.

### Git Commit Style

- Present tense, imperative mood ("Add feature" not "Added feature"), max 72 characters on the first line.
- Reference issues with `#123` after the first line.

## PR Requirements

- All CI checks pass (build, Pester on both editions, analyzer, docs drift).
- Tests cover new or changed behaviour; PSScriptAnalyzer reports zero errors.
- `CHANGELOG.md` `[Unreleased]` is updated.

## What AI Agents Should NOT Do

- Do not push, merge, publish to the Gallery, or comment on GitHub without the owner's explicit go.
- Do not modify CI workflow files without explicit instruction.
- Do not add new dependencies without discussing in an issue first.
- Do not commit secrets, credentials, or API keys.
- Do not push directly to `master`; always use pull requests.

## Template Differences

| Template default | This repo | Why |
| --- | --- | --- |
| PowerShell 7.6, Core only | PowerShell 3.0+, runs on 5.1 and 7 | MSPs run it from RMM agents on Windows PowerShell 5.1 |
| Sampler `test` task, Pester 6 | `Tests/test-local.ps1`, Pester 5.7 | Must run the suite under Windows PowerShell 5.1 |
| `Tests/Unit/{Module,Public,Private}`, one file per function | Four suite files under `Tests/` | Not split yet |
| `docs/` (help, examples, media) | `Docs/` (platyPS), `Examples/`, `Media/` at the root | `docs/` = `Docs/` on Windows |
| Changelog release task | Release notes by hand | The task cannot parse this CHANGELOG's 4-part versions |
| PlatyPS 1.x → `docs/help` | platyPS 0.14 via `Build/Update-Help.ps1` (+ MAML) | `Get-Help` on 5.1 uses the MAML |
| Tag-driven publish workflow | Manual `Publish-Module` | Owner publishes by hand |
