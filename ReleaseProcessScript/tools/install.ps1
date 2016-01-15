param($installPath, $toolsPath, $package, $project)

$DependencySets = $package.DependencySets
foreach ($DependecySet in $DependencySets)
{
  $Dependencies = $DependecySet.Dependencies
  foreach ($Dependency in $Dependencies)
  {
    if ($Dependency.Id -eq "Remotion.BuildTools.MSBuildTasks")
    {
      $BuildToolsVersion = $Dependency.VersionSpec.ToString()
    }
  }
}

$MarkerName = ".BuildProject"
$MarkerTemplate = 
"<?xml version=`"1.0`" encoding=`"utf-8`"?>
<!--Marks the path fo the releaseProcessScript config file-->
<configFile>
    <path>Build/Customizations/releaseProcessScript.config</path>
    <buildToolsVersion>$($BuildToolsVersion)</buildToolsVersion>
</configFile>"

if (-not (Test-Path $MarkerName))
{
    New-Item -Type file -Name $MarkerName -Value $MarkerTemplate
}
elseif ($BuildToolsVersion)
{
  [xml]$MarkerFile = Get-Content $MarkerName
  $FilePath = Resolve-Path $MarkerName

  if ([string]::IsNullOrEmpty($MarkerFile.configFile.buildToolsVersion))
  {
    $MarkerFile.configFile.buildToolsVersion = $BuildToolsVersion
    $MarkerFile.Save($FilePath)
  }
}