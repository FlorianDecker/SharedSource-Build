param($installPath, $toolsPath, $package, $project)

$MarkerName = ".BuildProject"
$MarkerTemplate = 
"<?xml version=`"1.0`" encoding=`"utf-8`"?>
<!--Marks the path fo the releaseProcessScript config file-->
<configFile>
    <path>Build/Customizations/releaseProcessScript.config</path>
</configFile>"

if (-not (Test-Path $MarkerName))
{
    New-Item -Type file -Name $MarkerName -Value $MarkerTemplate
}