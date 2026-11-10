function New-CWCHostLaunchUrl {
    <#
    .SYNOPSIS
        Builds the sc-<id>:// URL that opens the Control client, in the web client's format.

    .DESCRIPTION
        Mirrors getSchemeUrlFunc in the web client (SC.main.ts):
        {scheme}://{h}:{p}/{s}/{k}/{n}/{r}/{e}/{i}/{a}/{l}
        k, n, r, i, a and l are escaped like JavaScript's encodeURIComponent ([uri]::EscapeDataString);
        h, p, s and e are not. The result contains the access token: never log it.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds a string; changes nothing.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)][string]$Scheme,
        [Parameter(Mandatory = $True)][string]$RelayHost,
        [Parameter(Mandatory = $True)][int]$RelayPort,
        [Parameter(Mandatory = $True)][guid]$SessionID,
        [Parameter(Mandatory = $True)][string]$PublicKey,
        [Parameter(Mandatory = $True)][string]$AccessToken,
        [Parameter(Mandatory = $True)][ValidateSet('Support', 'Meeting', 'Access')][string]$SessionType,
        [string]$Title = '',
        [string]$ParticipantName = '',
        [string]$Attributes = 'None',
        [string]$LogonSessionID = ''
    )

    $Encode = { param([string]$Value) if ($Value) { [uri]::EscapeDataString($Value) } else { '' } }

    '{0}://{1}:{2}/{3}/{4}/{5}/{6}/{7}/{8}/{9}/{10}' -f @(
        $Scheme
        $RelayHost
        $RelayPort
        $SessionID.ToString()
        (& $Encode $PublicKey)
        (& $Encode $AccessToken)
        (& $Encode $ParticipantName)
        $SessionType
        (& $Encode $Title)
        (& $Encode $Attributes)
        (& $Encode $LogonSessionID)
    )
}
