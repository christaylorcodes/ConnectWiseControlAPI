function Find-CWCSession {
    <#
    .SYNOPSIS
        Finds sessions by session filter expression, name or ID (API secret connections).

    .DESCRIPTION
        Calls the RESTful API Manager extension. Searches all sessions of every type; results are not
        limited by role permissions or session groups.

        -Filter uses Control's session filter syntax, the same syntax as session group filters,
        e.g. "Name LIKE 'DESKTOP-*'" or "CustomProperty1 = 'Acme'".

    .PARAMETER Filter
        A session filter expression (GetSessionsByFilter).

    .PARAMETER Name
        Exact session name (GetSessionsByName). Single quotes are not allowed because the extension
        inserts the name into a filter expression without escaping.

    .PARAMETER GUID
        Session ID (GetSessionBySessionID).

    .EXAMPLE
        Find-CWCSession -Filter "GuestOperatingSystemName LIKE '*Server*'"

    .EXAMPLE
        Find-CWCSession -Name 'DESKTOP-01'

    .NOTES
        Requires Connect-CWC -ApiSecret and the RESTful API Manager extension.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(DefaultParameterSetName = 'Filter')]
    param(
        [Parameter(Mandatory = $True, ParameterSetName = 'Filter')]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,

        [Parameter(Mandatory = $True, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[^']*$")]
        [string]$Name,

        [Parameter(Mandatory = $True, ParameterSetName = 'GUID')]
        [guid]$GUID
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Filter' { $ServerMethod = 'GetSessionsByFilter'; $Argument = $Filter }
        'Name' { $ServerMethod = 'GetSessionsByName'; $Argument = $Name }
        'GUID' { $ServerMethod = 'GetSessionBySessionID'; $Argument = $GUID.ToString() }
    }

    # Unroll the returned array so each session goes down the pipeline
    Invoke-CWCServiceMethod -RestApi -Method $ServerMethod -Arguments $Argument -Idempotent | ForEach-Object { $_ }
}
