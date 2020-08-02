function Get-CWCSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateSet('Support','Access')]
        $Type,
        [string]$Group = 'All Machines',
        [string]$Search,
        [int]$Limit
    )

    $URI = "https://$($script:CWCServerConnection.Server)/Services/PageService.ashx/GetHostSessionInfo"

    switch($Type){
        'Support'   {$Number = 0}
        'Meeting'   {$Number = 1}
        'Access'    {$Number = 2}
        default     {Write-Error "Unknown Type, $Type";return}
    }

    $Body = ConvertTo-Json @($Number,@($Group),$Search,$null,$Limit)
    Write-Verbose $Body

    $WebRequestArguments = @{
        Uri = $URI
        Body = $Body
        Method = 'Post'
    }

    $Data =  Invoke-CWCWebRequest -Arguments $WebRequestArguments
    $Data.sessions
}
