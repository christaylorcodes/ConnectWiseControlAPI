<h1 align="center">
  <br>
  <img src=".\Media\control-horiz-master.webp" alt="logo" width = 75% ></a>
  <br>
  ConnectWise Control API
  <br>
</h1>


<p align="center">
    <a href="ConnectWiseControlAPI_Functions.md">List of Functions</a> •
    <a href="./Examples">Examples</a> •
    <a href="#install">Install</a> •
    <a href="https://github.com/christaylorcodes/GitHub-Template/blob/main/CONTRIBUTING.md">Contribute</a> •
    <a href="https://github.com/christaylorcodes/GitHub-Template/blob/main/CONTRIBUTING.md#reporting-bugs">Submit a Bug</a> •
    <a href="https://github.com/christaylorcodes/GitHub-Template/blob/main/CONTRIBUTING.md#suggesting-enhancements">Request a Feature</a>
</p>

<h4 align="center">

This is a PowerShell wrapper for ConnectWise Control

</h4>

<!-- Summary -->

This is a fork of ChrisTaylorCodes' CWC API module. I got tired of waiting for him to add MFA support so I did it myself. This module makes it easy to leverage PowerShell to automate tasks in Control. Please see his original project for any further details.



<!-- Summary -->


## [Install](https://github.com/Luke-Williams9/ConnectWiseControlAPI/archive/refs/heads/master.zip)

 The module can be installed by unzipping the master zip into one of your powershell modules folder, or by running the following one-liner:

```powershell
$ModuleName='ConnectWiseControlAPI';$parentFldr='ConnectWiseControlAPI-master';$u='https://github.com/Luke-Williams9/ConnectWiseControlAPI/archive/refs/heads/master.zip';If($IsWindows){$s=';'}else{$s=':'};$mp=($Env:PSModulePath.split($s) -like "$HOME*")[0];$td='.'+$ModuleName+'_temp';$tempdir=Join-Path '~' $td;$z=Join-Path $tempdir ($ModuleName + '.zip');New-Item -path '~' -name $td -type 'directory' -ErrorAction SilentlyContinue;Invoke-WebRequest -Uri $u -OutFile $z;Expand-Archive $z -DestinationPath $tempdir -Force;New-Item -path $mp -name $ModuleName -ItemType 'directory' -ErrorAction SilentlyContinue;Copy-Item (Join-Path $tempdir $parentFldr $moduleName) -Destination $mp -Force -Recurse;Get-Module -listAvailable $ModuleName
```

## Requirements

* Now supports MFA!

* Requires your Control server to use https.

<a href="https://github.com/Luke-Williams9/ConnectWiseControlAPI/blob/master/Examples/Connect_MFA.ps1">Connecting with MFA</a>

