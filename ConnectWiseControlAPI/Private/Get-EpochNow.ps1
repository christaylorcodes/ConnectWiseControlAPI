Function Get-EpochNow () {
    Return (New-TimeSpan (Get-Date 01.01.1970) (Get-Date)).TotalSeconds
}