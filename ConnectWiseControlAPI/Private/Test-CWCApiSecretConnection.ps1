function Test-CWCApiSecretConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # True when Connect-CWC was called with -ApiSecret (RESTful API Manager extension auth)
    [bool]($script:CWCServerConnection -and $script:CWCServerConnection.AuthType -eq 'ApiSecret')
}
