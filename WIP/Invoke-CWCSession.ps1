function Invoke-CWCSession {
    [CmdletBinding()]
    param (
        $Group,
        $GUID,
        $Type
    )

    try {
        $Token = New-CWCAccessToken -GUID $GUID -Group $Group -ErrorAction Stop
        $Details = Get-CWCSessionDetail -GUID $GUID -Group $Group
    }
    catch { return $_ }

    $Endpoint = 'Bin/i.t.Connect.ClientSetup.exe'

    $Splat = @{
        h = $script:CWCServerConnection.Server
        p = 80
        k = [System.Web.HTTPUtility]::UrlEncode($(($script:CWCServerConnection['Headers']['Set-Cookie'] -split '; ')[0] -replace '.ASPXAUTH=', ''))
        s = $GUID
        i = $Details.Session.GuestMachineName
        e = $Type
        y = 'Host'
        n = [System.Web.HTTPUtility]::UrlEncode($Token)
        a = 'None'
    }
    $AppId = 'sc-2fed754e7d45a198'
    $CLI = "$($AppId)://$($Splat.h):$($Splat.p)/$($Splat.s)/$($Splat.k)/$($Splat.n)//$($Splat.e)/$($Splat.i)/$($Splat.a)/"
    Write-Verbose $CLI

    #$Cache = Invoke-RestMethod "https://$($script:CWCServerConnection.Server)/Script.ashx?__Cache=1b1722c7-9687-46e3-8b05-7e6ea2c7d5c2"
    #$Cache | Select-String 'context'
    try {
        Start-Process $CLI
    }
    catch {
        # if launch error download installer
        $nvCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $Splat | ForEach-Object { $nvCollection.Add($_.Name, $_.Value) }

        $WebRequestArguments = @{
            Endpoint = '{0}?{1}' -f $Endpoint, $nvCollection.ToString()
            Method   = 'Get'
            OutFile  = 'C:\temp\test.exe'
        }

        #Invoke-CWCWebRequest -Arguments $WebRequestArguments
    }
}