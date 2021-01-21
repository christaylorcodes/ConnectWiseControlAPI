function Connect-CWC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string] $Server,
        [Parameter(Mandatory = $True)][pscredential] $Credentials,
        [switch]$Force,
        [string] $aspxauth
        [string] $CloudInstanceAuth
    )

    if ($script:CWCServerConnection -and !$Force) {
        Write-Verbose "Using cached Authentication information."
        return
    }

    $Server = $Server -replace("http.*:\/\/",'')
    
    if($credentials -ne "CookieAuth") {
    $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($Credentials.UserName):$($Credentials.GetNetworkCredential().Password)"))
    $Headers = @{
        'authorization' = "Basic $encodedCredentials"
        'content-type' = "application/json; charset=utf-8"
        'origin' = "https://$Server"
    }
    }else{
    $cookieAuth=$true
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession    
    $cookie = New-Object System.Net.Cookie 

        $cookie.Name = ".ASPXAUTH"
        $cookie.Value = ""
        $cookie.Domain = "$server"
    $session.Cookies.Add($cookie);
        $cookie.Name = "CloudInstanceAuth"
        $cookie.Value = "F20RqixToMuhK9aW94FNfbjB95Bc5zCI+WpynWWANPpoAAAGcXVjYmpsG0Nsb3VkIEFjY291bnQgQWRtaW5pc3RyYXRvcgIAAACW4meSQJlw+engri1CUmfFR6OyLUIAAQZxdWNiamxOR8X6L68tQgAB"
        $cookie.Domain = "$server"
    $session.Cookies.Add($cookie);
        $cookie.Name = "Settings"
        $cookie.Value = "%7B%22extendedCss%22%3A%7B%22grid-resizable-column-edges%22%3A%7B%7D%7D%2C%22selectedTabBySessionTypeMap%22%3A%7B%222%22%3A%22General%22%7D%2C%22collapsedPanelMap%22%3A%7B%22Screenshot%22%3Atrue%7D%7D"
        $cookie.Domain = "$server"
    $session.Cookies.Add($cookie);
    
     $Headers = @{        
        'content-type' = "application/json; charset=utf-8"
        'origin' = "https://$Server"
    }
    
    }
    

    $script:CWCServerConnection = @{
        Session = $Session        
        Server = $Server
        Headers = $Headers
    }

    Write-Verbose '$CWCServerConnection, variable initialized.'
}
