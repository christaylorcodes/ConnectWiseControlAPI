function New-CWCSession {
    <#
    .SYNOPSIS
        Creates a session.

    .DESCRIPTION
        Creates a session and returns the new session ID. Works with both connection types:

        -Credentials: PageService.CreateSession. Requires the create permission for the session type;
        the session host is the connected user.

        -ApiSecret: the RESTful API Manager extension's CreateSession. The session host is the
        extension's RESTfulUserName setting ("RESTful API" by default).

    .PARAMETER Type
        Support, Meeting or Access.

    .PARAMETER Name
        Session name.

    .PARAMETER IsPublic
        Make the session publicly listed on the guest page.

    .PARAMETER Code
        Session join code.

    .PARAMETER CustomPropertyValues
        Custom property values in order (CustomProperty1, CustomProperty2, ...).

    .EXAMPLE
        New-CWCSession -Type Support -Name 'Ticket 12345' -Code '12345'

    .NOTES
        Not retried on HTTP 500: a retry after the server created the session would create a second one.
        Author: Chris Taylor

    .LINK
        https://github.com/christaylorcodes/ConnectWiseControlAPI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([guid])]
    param(
        [Parameter(Mandatory = $True)]
        [ValidateSet('Support', 'Meeting', 'Access')]
        [string]$Type,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [switch]$IsPublic,

        [string]$Code = '',

        [string[]]$CustomPropertyValues = @()
    )

    # Same signature on both services:
    # CreateSession(SessionType sessionType, string name, bool isPublic, string code, string[] customPropertyValues)
    $CreateSessionArguments = @(
        $script:CWCSessionType[$Type],
        $Name,
        [bool]$IsPublic,
        $Code,
        @($CustomPropertyValues)
    )

    if ($PSCmdlet.ShouldProcess($Name, "Create $Type session")) {
        if (Test-CWCApiSecretConnection) {
            $Result = Invoke-CWCServiceMethod -RestApi -Method CreateSession -Arguments $CreateSessionArguments
        }
        else {
            $Result = Invoke-CWCServiceMethod -Service PageService -Method CreateSession -Arguments $CreateSessionArguments
        }
        if ($Result) { [guid]$Result }
    }
}
