function Get-CWCHostLaunchContext {
    <#
    .SYNOPSIS
        Returns the server's client launch settings: URL scheme, relay host and port, public key.

    .DESCRIPTION
        The web client reads these from SC.context in Script.ashx (instanceUrlScheme and clp = h, p, k).
        Script.ashx is public, so no authentication is sent. The result is cached on the connection;
        Connect-CWC -Force starts a new connection and so a fresh read.
    #>
    [CmdletBinding()]
    param()

    $Connection = $script:CWCServerConnection
    if ($Connection.HostLaunch) { return $Connection.HostLaunch }

    $Uri = "https://$($Connection.Server)/Script.ashx"
    try {
        $Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction Stop
    }
    catch {
        return Write-Error "Could not read the client launch settings from $Uri : $($_.Exception.Message)"
    }

    $Content = $Response.Content
    if ($Content -is [byte[]]) { $Content = [Text.Encoding]::UTF8.GetString($Content) }

    # The scheme is used as a shell-executed URL, so accept only the sc-<id> form the web client uses.
    $SchemeMatch = [regex]::Match("$Content", '"instanceUrlScheme"\s*:\s*"(sc-[A-Za-z0-9]+)"')
    $ClpMatch = [regex]::Match("$Content", '"clp"\s*:\s*(\{[^{}]*\})')
    if (-not $SchemeMatch.Success -or -not $ClpMatch.Success) {
        return Write-Error "The server at $($Connection.Server) did not publish client launch settings (instanceUrlScheme, clp) in Script.ashx. This server version may not be supported."
    }

    try { $Clp = $ClpMatch.Groups[1].Value | ConvertFrom-Json -ErrorAction Stop }
    catch { return Write-Error "Could not parse the client launch settings from $Uri." }

    $Port = 0
    if (-not ("$($Clp.h)" -match '^[A-Za-z0-9.:\[\]-]+$') -or
        -not [int]::TryParse("$($Clp.p)", [ref]$Port) -or $Port -lt 1 -or $Port -gt 65535 -or
        -not $Clp.k) {
        return Write-Error "The client launch settings from $Uri are incomplete or invalid (relay host, port or key)."
    }

    $Context = @{
        Scheme    = $SchemeMatch.Groups[1].Value
        RelayHost = "$($Clp.h)"
        RelayPort = $Port
        PublicKey = "$($Clp.k)"
    }
    $Connection.HostLaunch = $Context
    $Context
}
