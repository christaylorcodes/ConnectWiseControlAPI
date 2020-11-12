function Connect-CWC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Server,
        [Parameter(Mandatory = $True)]
        [pscredential]$Credentials,
        [switch]$Force
    )

    if ($script:CWCServerConnection -and !$Force) {
        Write-Verbose "Using cached Authentication information."
        return
    }

    $Server = $Server -replace("http.*:\/\/",'')

    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Credentials.UserName):$($Credentials.GetNetworkCredential().Password)"))
    $Headers = @{
        'authorization' = "Basic $encodedCredentials"
        'content-type' = "application/json; charset=utf-8"
        'origin' = "https://$Server"
    }

    $script:CWCServerConnection = @{
        Server = $Server
        Headers = $Headers
    }

    Write-Verbose '$CWCServerConnection, variable initialized.'
}
