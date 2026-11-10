function Invoke-CWCLogout {
    <#
    .SYNOPSIS
        Best-effort AuthenticationService.TryLogout for an MFA connection the module no longer uses, so
        its login cookie stops working on the server too. Never fails the caller.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [hashtable]$Connection
    )

    # Invoke-CWCServiceMethod sends on the module's connection: point it at the old one briefly
    $Current = $script:CWCServerConnection
    try {
        $script:CWCServerConnection = $Connection
        $null = Invoke-CWCServiceMethod -Service AuthenticationService -Method TryLogout -ErrorAction Stop
        Write-Verbose "Logged out the previous MFA login to https://$($Connection.Server)."
    }
    catch {
        Write-Verbose "Could not log out the previous MFA login: $($_.Exception.Message)"
    }
    finally {
        $script:CWCServerConnection = $Current
    }
}
