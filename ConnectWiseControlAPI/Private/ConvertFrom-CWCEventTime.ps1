function ConvertFrom-CWCEventTime {
    <#
    .SYNOPSIS
        Converts a PageService session event's Time to an absolute UTC DateTime.

    .DESCRIPTION
        PageService.GetSessionDetails reports each event's Time as the milliseconds elapsed before the
        response (not an epoch). Converting to an absolute time lets callers compare events across
        separate polls.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $True)]
        $SessionEvent
    )

    [DateTime]::UtcNow.AddMilliseconds(-[double]$SessionEvent.Time)
}
