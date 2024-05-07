#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue -Recurse )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue -Recurse )

#Dot source the files
Foreach($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    } Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Set Security Protocol
if([Net.SecurityProtocolType]::Tls) {
    [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls
}

$script:InternalUserSource = 'InternalMembershipProvider'
$script:defaultGroup = 'All Machines by Company'
$script:timeZoneOffset = New-Timespan -hours (((get-timezone).baseUtcOffset).hours + (Get-Date).IsDaylightSavingTime()) -minutes ((get-timezone).baseUtcOffset).minutes

# Export Public functions ($Public.BaseName) for WIP modules
Export-ModuleMember -Function $Public.Basename