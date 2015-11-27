param($installPath, $toolsPath, $package)

Import-Module (Join-Path $toolsPath ReleaseProcessScript.psm1) -DisableNameChecking -Force

Write-Host "Type 'get-help ReleaseProcessScript' to see all available ReleaseProcessScript commands"