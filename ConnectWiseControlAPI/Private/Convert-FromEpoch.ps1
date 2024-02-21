Function Convert-FromEpoch () {
    <#
        .SYNOPSIS
        Convert linux epoch time to a DateTime object

        .DESCRIPTION
        Pipe a string

        .PARAMETER unixTime
        Epoch time in a string
        
        .INPUTS
        Pipe in the epoch time

        .OUTPUTS
        A DateTime Object - UTC time

        .EXAMPLE
        $time = $unixTime | fromEpoch
    #>
    [cmdletBinding()]
        param (
            [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)][string]$unixTIme
        )
    Return (Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($unixTime))
}