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
    $EncodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Credentials.UserName):$($Credentials.GetNetworkCredential().Password)"))
    $Headers = @{
        'authorization' = "Basic $EncodedCredentials"
        'content-type' = "application/json; charset=utf-8"
        'origin' = "https://$Server"
    }

    $FrontPage = Invoke-WebRequest -Uri $Headers.origin -Headers $Headers -UseBasicParsing
    $Regex = [Regex]'(?<=antiForgeryToken":")(.*)(?=","isUserAdministrator)'
    $Match = $Regex.Match($FrontPage.content)
    if($Match.Success){ $Headers.'x-anti-forgery-token' = $Match.Value.ToString() }
    else{ Write-Verbose 'Unable to find anti forgery token. Some commands may not work.' }

    $script:CWCServerConnection = @{
        Server = $Server
        Headers = $Headers
    }
    Write-Verbose ($script:CWCServerConnection | Out-String)

    try{
        $null = Get-CWCSessionGroup -ErrorAction Stop
        Write-Verbose '$CWCServerConnection, variable initialized.'
    }
    catch{
        Remove-Variable CWCServerConnection -Scope script
        Write-Verbose 'Authentication failed.'
        Write-Error $_
    }
}
