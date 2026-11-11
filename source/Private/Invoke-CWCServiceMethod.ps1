function Invoke-CWCServiceMethod {
    <#
    .SYNOPSIS
        Calls one ScreenConnect web service method. Every public function's API call goes through here.

    .DESCRIPTION
        Builds the endpoint, serializes the method arguments as a JSON array and passes the request to
        Invoke-CWCWebRequest (transport: auth headers, cookies, retry, error handling).

        -Service       built-in service:        Services/<Service>.ashx/<Method>          (credentials connections)
        -RestApi       RESTful API Manager:     App_Extensions/<RestApi ID>/Service.ashx/<Method>  (API secret connections)
        -ExtensionID   any other extension:     App_Extensions/<ID>/Service.ashx/<Method>  (credentials connections)

    .PARAMETER Arguments
        The server method's arguments, in order. Omit for methods without arguments (no body is sent).

    .PARAMETER Idempotent
        The call is safe to repeat (reads, "set to value" updates). Only idempotent calls are retried on
        HTTP 500: a 500 after the server acted would otherwise repeat the action (a second command, note,
        wake or delete).

    .PARAMETER Sensitive
        The arguments contain a secret (password). The body is left out of verbose and debug output.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Service')]
    param(
        [Parameter(Mandatory = $True, ParameterSetName = 'Service')]
        [ValidateSet('PageService', 'SecurityService', 'AuditService', 'SessionGroupService', 'AuthenticationService')]
        [string]$Service,

        [Parameter(Mandatory = $True, ParameterSetName = 'RestApi')]
        [switch]$RestApi,

        [Parameter(Mandatory = $True, ParameterSetName = 'Extension')]
        [guid]$ExtensionID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Method,

        [object[]]$Arguments,

        [switch]$Idempotent,

        [switch]$Sensitive
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Service' { $Endpoint = "Services/$Service.ashx/$Method" }
        'RestApi' { $Endpoint = "App_Extensions/$($script:CWCRestApiExtensionID)/Service.ashx/$Method" }
        'Extension' { $Endpoint = "App_Extensions/$ExtensionID/Service.ashx/$Method" }
    }

    $WebRequestArguments = @{
        Endpoint = $Endpoint
        Method   = 'Post'
    }

    if ($PSBoundParameters.ContainsKey('Arguments')) {
        # -InputObject keeps a one-element list as a JSON array; -Depth keeps nested event entries intact.
        # PS 5.1 serializes an empty array as an empty string, so send '[]' explicitly.
        if (@($Arguments).Count -eq 0) { $WebRequestArguments.Body = '[]' }
        else { $WebRequestArguments.Body = ConvertTo-Json -InputObject @($Arguments) -Depth 10 }
    }

    if ($Sensitive) { Write-Verbose "POST $Endpoint (arguments redacted)" }
    else { Write-Verbose "POST $Endpoint $($WebRequestArguments.Body)" }

    # 3 retries with 2, 4, 8 second waits
    $MaxRetry = 0
    if ($Idempotent) { $MaxRetry = 3 }

    Invoke-CWCWebRequest -Arguments $WebRequestArguments -MaxRetry $MaxRetry -SensitiveBody:$Sensitive
}
