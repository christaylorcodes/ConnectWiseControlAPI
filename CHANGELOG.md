# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Planned as 0.5.0.0 (the module manifest already carries this version; 0.4.0.0 is on the PowerShell Gallery).

### Added

- GitHub community files: CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, issue templates, PR template
- `.editorconfig` for consistent editor formatting
- `.gitattributes` for line ending normalization and diff drivers
- `.PSScriptAnalyzerSettings.psd1` with 60+ rules targeting PS 5.1+ compatibility
- `CHANGELOG.md` (this file)
- `Connect-CWC -ApiSecret`: second authentication method using the RESTful API Manager extension's
  `RESTfulAuthenticationSecret` (sent as `CTRLAuthHeader`). Works with MFA-enforced servers.
  `Get-CWCSessionDetail`, `Update-CWCSessionName`, `New-CWCSession`, `Add-CWCSessionNote`,
  `Send-CWCSessionMessage`, `Send-CWCToolboxItem` and `Invoke-CWCCommand` work on both connection types
  (`Invoke-CWCCommand` queues only on API-secret connections; output is not retrieved); other functions
  return an error naming the required auth method. `-Origin` overrides the Origin header for servers
  with `RESTfulAllowedOrigin` set
- `Connect-CWC` keeps the previous connection when a `-Force` reconnect fails, and warns when a cached
  connection for a different server or auth method is reused
- `Find-CWCSession` (`-Filter`/`-Name`/`-GUID`; API secret only), `New-CWCSession`,
  `Add-CWCSessionNote`, `Send-CWCSessionMessage`, `Send-CWCToolboxItem`. On credentials connections the
  last three queue session events (AddedNote 32, QueuedMessage 45, QueuedTool 47) and take `-Group`
- Live smoke test script `Tests/Live/Invoke-CWCLiveSmokeTest.ps1` (read-only by default; `-AllowWrites`
  acts on one chosen test session and cleans up its notes; `-MfaUserName` probes the MFA login flow)
- `Get-CWCRemoteWorkforceLaunchURL` (by `-GUID`, pipeline, or `-SessionName`), replacing `Get-CWCLauncURL`
- `Get-CWCRemoteWorkforceSession` lists the calling user's assigned machines (`GetRemoteWorkforceSessions`)
- `Initialize-CWCRemoteWorkforceSessionGroup` creates/repairs the extension's session group
  (`EnsureCorrectSessionGroupExists`)
- `Remove-CWCHostFromSession` disconnects one connection from a session (QueuedForceDisconnect, event 48);
  contributed by turbo-donkey (#28). Takes single `-SessionID`/`-ConnectionID` values and prompts by default
- `Remove-CWCSession -Uninstall` queues `QueuedUninstallAndDelete` (event 100) so the Access client is
  uninstalled as well; without it the session record is only deleted (`DeletedSession`, event 21)

### Deprecated

- `Get-CWCLauncURL` now forwards to `Get-CWCRemoteWorkforceLaunchURL` with a warning; removal in v1.0

### Changed

- Expanded `.gitignore` to cover OS files, IDEs, build artifacts, and secrets
- Updated `README.md` links to use local community files instead of external GitHub-Template references
- `Connect-CWC` validates credentials with `PageService/GetEligibleHosts` (any permission) instead of
  `Get-CWCSessionGroup` (requires ManageSessionGroups), so non-admin accounts can connect
- `Get-CWCAuditLog` `-StartDate`/`-EndDate` default to the last 24 hours; `-IncludeSessionCaptures` is
  deprecated (the server no longer accepts it) and now only emits a warning
- All API calls go through one internal helper that builds the endpoint and serializes arguments the same
  way everywhere (single items, empty lists and nested event entries)
- HTTP 500 retries are limited to calls that are safe to repeat (reads, "set to value" updates). Before,
  a 500 returned after the server had acted could queue a second command, wake, delete or user. Retries
  now wait 2, 4 and 8 seconds (3 retries); the old 2-32 ms waits gave a struggling server no time to
  recover. A final 500 error now includes the server's error message
- Session event type numbers are kept in one table, verified against a live server's web client
- **Breaking:** `Remove-CWCSession` prompts by default (`ConfirmImpact = 'High'`), confirms each session
  separately and rejects an empty GUID. Unattended scripts must add `-Confirm:$false`
- `Connect-CWC` reports a failed login with its likely causes. Wrong credentials are not rejected with a
  401: the request runs as an anonymous user and fails with "Needs permission"
- `Get-CWCLastContact` returns an error when no connection event is found, instead of the current time

### Fixed

Endpoint calls audited against the Control server's `Services/*.ashx` source:

- `Invoke-CWCWake` called `PageService.AddEventToSessions`, which no longer exists; it now queues wake
  events (type 43) through `AddSessionEvents`
- `Get-CWCAuditLog` sent 6 arguments to `QueryAuditLog`, which takes 5 (the capture flag landed in the
  event-type slot); local times were also sent with a `Z` suffix and are now converted to UTC
- `Get-CWCSessionGroup` now calls the documented `GetSessionGroups` (POST) method instead of the
  undocumented `session-groups` GET route (both return the same data on Control 26.7.6; not a bug fix)
- `Add-CWCRemoteWorkforceRequiredRole` now calls the extension's own
  `EnsureRemoteWorkforceSecurityRoleExists` instead of building the role with `CreateRole`: it is
  idempotent, honors the extension's `RoleName`/`SessionGroupName` settings, and sets `IsRoleCreated`
- `Update-CWCUser` erased the user's Comment field on every update
- `Invoke-CWCWebRequest -Debug` printed the Basic auth header and anti-forgery token; auth headers are now redacted
- `-Verbose`/`-Debug` output of `New-CWCUser`/`Update-CWCUser` included the password; request bodies holding
  secrets are now redacted
- Cookies set by the server were sent back as a `Set-Cookie` request header, so the server never received
  them; credentials connections now keep a web session (likely cause of "Invalid anti-forgery token", #22)
- The anti-forgery token regex depended on JSON key order on the server's front page
- Failed requests left auth headers on the request object kept in `$Error` (PS 5.1 and PS 6+); they are now stripped
- `Invoke-CWCCommand` compares event times on the server's clock, so poll latency can no longer make it
  skip a fast command's output or return a previous command's output
- On PS 5.1, a non-JSON error body (IIS 401/404 page) threw while building the error and hid the real status
- `Get-CWCLastContact -Quiet -Seconds` was off by the local UTC offset (mixed UTC and local DateTimes)
- `Remove-CWCSession` packed multiple GUIDs into a single event entry; it now sends one entry per session
- `Invoke-CWCCommand` polled the rate-limited `GetSessionDetails` once a second for everything, including
  the guest screenshot; it now requests events only (`Get-CWCSessionDetail -Include Events`), and
  `Get-CWCLastContact` requests events and connections only
- `Get-CWCSessionDetail -Include` selects which parts of the session details to return (SessionDetailsItems
  flags: SessionInfo 1, GuestScreenshotContent 4, Events 8, Connections 16, read from the web client)

Extension calls audited against the Remote Workforce 1.3.16 `App_Extensions/2c4f522f…/Service.ashx` source:

- `Get-CWCLauncURL` sent 6 arguments to `GetLaunchUrlForSessionId`, which takes 1 (the session ID),
  including a plaintext password the server never used
- The `Launcher` extension folder was the Remote Workforce extension; functions moved under `Remote Workforce/`

## [0.4.0.0]

Published to the PowerShell Gallery from commit 889b56b; the repository manifest was not bumped at the time.

### Fixed

- `Get-CWCSession` uses the `GetLiveData` endpoint (#23)
- Error handling on PowerShell 7 no longer calls `GetResponseStream` (#15)

## [0.3.5.0] - 2026-02-03

### Fixed

- Retry logic in `Invoke-CWCWebRequest` moved into catch block (was dead code in try block)
- TLS upgraded from 1.0 to 1.2 in module loader
- Credential leak removed from verbose output in `Connect-CWC`
- Password exposure removed from `-WhatIf` output in `New-CWCUser` and `Update-CWCUser`
- SecureString BSTR memory properly zeroed in `Update-CWCUser`
- Error handling added to `Connect-CWC` initial server request
- Swallowed errors fixed in `Invoke-CWCCommand` and `Get-CWCLastContact` (changed `return $_` to `Write-Error`)
- Script-scope error variable leak fixed in `Invoke-CWCWebRequest`
- Undefined variables fixed in `Get-CWCLauncURL` (added as parameters)
- Manual JSON string replaced with `ConvertTo-Json` in `New-CWCAccessToken`
- `$Group` parameter types standardized to `[string]` across all functions
- `ShouldProcess` added to `Add-CWCRemoteWorkforceRequiredRole`
- UTC/local time mixing fixed in epoch calculations in `Get-CWCLastContact`

## [0.3.4.0] - 2024-01-01

### Added

- `Get-CWCLiveData` function for real-time session data
- Session event support via `AddSessionEvents` endpoint

### Changed

- Build configuration updates

---

[Unreleased]: https://github.com/christaylorcodes/ConnectWiseControlAPI/compare/889b56b...HEAD
[0.4.0.0]: https://github.com/christaylorcodes/ConnectWiseControlAPI/commit/889b56b
[0.3.5.0]: https://github.com/christaylorcodes/ConnectWiseControlAPI/compare/v0.3.4.0...v0.3.5.0
[0.3.4.0]: https://github.com/christaylorcodes/ConnectWiseControlAPI/releases/tag/v0.3.4.0
