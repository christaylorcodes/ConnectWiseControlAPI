function Get-CWCAntiForgeryToken {
    <#
    .SYNOPSIS
        Returns the anti-forgery token from the Control front page HTML, or $null.

    .DESCRIPTION
        Matches only a token-shaped value, so a change in the page's JSON key order can't break the
        capture (an old pattern required "isUserAdministrator" to follow) and no other page content is taken.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Content
    )

    $Match = [regex]::Match("$Content", 'antiForgeryToken":"([A-Za-z0-9+/=_-]{16,512})"')
    if ($Match.Success) { $Match.Groups[1].Value } else { $null }
}
