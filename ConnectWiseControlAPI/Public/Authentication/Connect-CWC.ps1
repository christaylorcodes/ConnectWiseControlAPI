function Connect-CWC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Server,
        [Parameter(Mandatory = $True)]
        [pscredential]$Credentials,
        [securestring]$secret,
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
    if ($secret) {
        $Headers.'X-One-Time-Password' = (Get-OTP $secret -verbose).code
    }
    $FrontPage = Invoke-WebRequest -Uri $Headers.origin -Headers $Headers -UseBasicParsing
    $Regex = [Regex]'(?<=antiForgeryToken":")(.*)(?=","isUserAdministrator)'
    $Match = $Regex.Match($FrontPage.content)
    if ($Match.Success) { 
        $Headers.'x-anti-forgery-token' = $Match.Value.ToString() 
    } else { 
        Write-Verbose 'Unable to find anti forgery token. Some commands may not work.' 
    }
    Write-Verbose "Result:"
    Write-Verbose $FrontPage.headers
    $LoginResult = $FrontPage.headers.'X-Login-Result'
    $script:CWCServerConnection = @{
        Server = $Server
        Headers = $Headers
        Secret = $secret
    }
    if ($LoginResult) {
        Remove-Variable CWCServerConnection -Scope script
        Throw ("Login failed: " + $LoginResult)
    } else {
        Write-Verbose "Login Success. "
        Write-Verbose $Script:CWCServerConnection
        Return $true
    }
}
