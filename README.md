<h1 align="center">
  <br>
  <img src=".\Media\control-horiz-master.webp" alt="logo" width = 75% ></a>
  <br>
  ConnectWiseControlAPI
  <br>
</h1>

<h4 align="center">

A PowerShell wrapper for the ConnectWise ScreenConnect (formerly ConnectWise Control) web API

</h4>

<div align="center">

[![CI](https://github.com/christaylorcodes/ConnectWiseControlAPI/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/christaylorcodes/ConnectWiseControlAPI/actions/workflows/ci.yml)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/8aa3633cda3d41d5baa5e9f595b8124f)](https://www.codacy.com/gh/christaylorcodes/ConnectWiseControlAPI/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=christaylorcodes/ConnectWiseControlAPI&amp;utm_campaign=Badge_Grade)
[![Gallery](https://img.shields.io/powershellgallery/v/ConnectWiseControlAPI?label=PS%20Gallery&logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/ConnectWiseControlAPI)
[![Donate](https://img.shields.io/badge/$-donate-ff69b4.svg?maxAge=2592000&amp;style=flat)](https://github.com/christaylorcodes/GitHub-Template/blob/main/DONATE.md)

</div>
<p align="center">
    <a href="ConnectWiseControlAPI_Functions.md">List of Functions</a> •
    <a href="./Examples">Examples</a> •
    <a href="#install">Install</a> •
    <a href=".github/CONTRIBUTING.md">Contribute</a> •
    <a href=".github/CONTRIBUTING.md#reporting-bugs">Submit a Bug</a> •
    <a href=".github/CONTRIBUTING.md#suggesting-enhancements">Request a Feature</a>
</p>

<!-- Summary -->

This module makes it easy to leverage PowerShell to automate tasks in ScreenConnect.

ConnectWise renamed Control back to ScreenConnect. The module keeps its name and its `CWC` command names, so
scripts don't need renaming. Version 0.5.0 does change some behaviour: see [Upgrading from 0.4](#upgrading-from-04).

<!-- Summary -->

## [Install](https://www.powershellgallery.com/packages/ConnectWiseControlAPI)

 The module can be easily installed from the [PowerShellGallery](https://www.powershellgallery.com/packages/ConnectWiseControlAPI)

```powershell
Install-Module 'ConnectWiseControlAPI'
```

>If you are having issues accessing the PowerShell Gallery check out my [repair script](https://github.com/christaylorcodes/Initialize-PSGallery)

### Upgrading from 0.4

0.5.0 changes some behaviour. Check your scripts before you update:

* `Remove-CWCSession`, `Remove-CWCSessionNote` and `Remove-CWCHostFromSession` ask for confirmation by default.
  Unattended scripts must add `-Confirm:$false`; without it they fail and remove nothing.
* `Connect-CWC` without `-Force` now switches to a different server, sign-in method or user. Before, it kept the
  old connection.
* `Get-CWCLastContact` returns an error when it finds no connection event. Before, it returned the current time.
* `Get-CWCAuditLog` covers the last 24 hours unless you pass `-StartDate` and `-EndDate`.
* `Get-CWCSession -Type Support` and `-Type Meeting` without `-Group` read the `All Sessions` and `All Meetings`
  groups. Before, they read `All Machines`, which holds Access sessions.
* A request that fails with HTTP 500 is repeated only when repeating is safe (reads and "set to value" updates).

The full list is in the [changelog](CHANGELOG.md).

## Requirements

* Requires your ScreenConnect server to use https.

* One of three authentication methods:

  * **Credentials** (`Connect-CWC -Credentials`): an account without MFA. Use a complex username and
    password. All functions except `Find-CWCSession` are available, limited by the account's permissions.

  * **Credentials with MFA** (`Connect-CWC -Credentials` plus `-Mfa`, `-OneTimeCode` or `-TotpSecret`):
    an account that requires MFA, signed in the way the web page does. Same functions as credentials.
    `-Mfa` asks for the code at the console (authenticator app, email or SMS). `-TotpSecret` computes the
    authenticator-app code for unattended scripts from the account's TOTP secret (`ms:...` or Base32);
    keep that secret in a secret store, and note that storing it next to the password makes MFA a
    single factor. The login expires on the server; run `Connect-CWC` again before each batch of work
    (a still-valid login is reused with one check call).

    ```powershell
    Connect-CWC -Server 'screenconnect.example.com' -Credentials (Get-Credential) -Mfa

    # Unattended, with Microsoft.PowerShell.SecretManagement
    Connect-CWC -Server 'screenconnect.example.com' -Credentials (Get-Secret 'CWC-Login') -TotpSecret (Get-Secret 'CWC-TOTP')
    ```

  * **API secret** (`Connect-CWC -ApiSecret`): install the **RESTful API Manager** extension and set its
    `RESTfulAuthenticationSecret` setting to a long random value. Works when every account requires MFA.
    Available functions: `Find-CWCSession`, `New-CWCSession`, `Get-CWCSessionDetail`,
    `Update-CWCSessionName`, `Invoke-CWCCommand` (queues the command but does not return its output),
    `Add-CWCSessionNote`, `Send-CWCSessionMessage`, `Send-CWCToolboxItem`. The secret bypasses
    ScreenConnect's role permissions and acts on every session, so protect it like an administrator password.
    If the extension's `RESTfulAllowedOrigin` setting is set, pass a matching `-Origin`.

    ```powershell
    $Secret = Read-Host -AsSecureString -Prompt 'RESTful API secret'
    Connect-CWC -Server 'screenconnect.example.com' -ApiSecret $Secret
    Find-CWCSession -Filter "Name LIKE 'DESKTOP-*'"
    ```

## Tutorials & Resources

In-depth tutorials on [christaylor.codes](https://christaylor.codes):

- [Introducing ConnectWiseControlAPI](https://christaylor.codes/powershell/msp/connectwisecontrolapi/2023/03/15/introducing-connectwisecontrolapi.html) - Module overview and key features
- [Getting Started with ConnectWiseControlAPI](https://christaylor.codes/powershell/msp/connectwisecontrolapi/2023/03/22/getting-started-connectwisecontrolapi.html) - Authentication, setup, and first commands
- [Cleaning Duplicate Control Sessions](https://christaylor.codes/powershell/msp/connectwisecontrolapi/2023/03/29/cleaning-duplicate-control-sessions.html) - Practical session management automation
- [Building PowerShell API Wrappers](https://christaylor.codes/powershell/development/connectwisecontrolapi/2023/12/05/building-powershell-api-wrappers.html) - Design patterns behind the module

## [Contributing](.github/CONTRIBUTING.md)

If you use this project please give it a star and follow so you can get updated when new features are released. This also lets me know what projects are getting used and what ones I should dedicate more time to. If you want to get more involved please see the [contributing page](.github/CONTRIBUTING.md). Projects need all kinds of help even if you don't know how to code.

Want to share something you created using the module? Submit it to be featured as a Community Package.

## Donating

If you cant take time to contribute maybe you would like to help another way.

It takes time to maintain this project. Does the time spent on this module help you do cool things? Is that time worth a beer or two?

Donations allow me to spend more time on this project and implement your feature requests.
