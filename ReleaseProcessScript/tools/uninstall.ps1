param($installPath, $toolsPath, $package)

$DependencySets = $package.DependencySets

foreach ($DependecySet in $DependencySets)
{
  $Dependencies = $DependecySet.Dependencies
  foreach ($Dependency in $Dependencies)
  {
    if ($dependency.Id -eq "Remotion.BuildTools.MSBuildTasks")
    {
      $BuildToolsVersion = $Dependency.VersionSpec.ToString()
    }
  }
}

$MarkerName = ".BuildProject"
if (Test-Path $MarkerName)
{
  $FilePath = Resolve-Path $MarkerName
  [xml]$MarkerFile = Get-Content $MarkerName

  if ($MarkerFile.configFile.buildToolsVersion -eq $BuildToolsVersion)
  {
    $MarkerFile.configFile.buildToolsVersion = ""
    $MarkerFile.Save($FilePath)
  }
} 
