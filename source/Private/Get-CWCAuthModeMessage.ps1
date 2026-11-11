function Get-CWCAuthModeMessage {
    <#
    .SYNOPSIS
        The error text for a command used with the wrong Connect-CWC authentication method.

    .PARAMETER Command
        Name of the public command the user ran.

    .PARAMETER Required
        The authentication method the command needs.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $True)]
        [string]$Command,

        [Parameter(Mandatory = $True)]
        [ValidateSet('Credentials', 'ApiSecret')]
        [string]$Required
    )

    if ($Required -eq 'Credentials') {
        return "$Command is not available when connected with -ApiSecret (RESTful API Manager). Connect with 'Connect-CWC -Credentials' to use it (for an account that requires MFA, add -Mfa, -OneTimeCode or -TotpSecret)."
    }
    "$Command requires the RESTful API Manager extension. Connect with 'Connect-CWC -ApiSecret' to use it."
}
