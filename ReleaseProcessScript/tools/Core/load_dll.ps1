$Location = $PSScriptRoot

function Load-Dependency-Dll ()
{
    $MarkerFile = Get-Marker-File
    $BuildToolsVersion = $MarkerFile.configFile.buildToolsVersion

    $SolutionDirectory = git rev-parse --show-toplevel
    #$package = Get-Package -Filter -"Remotion.BuildTools.MSBuildTasks"
    #Todo: Remove Hardcoded path
    $BuildToolsPackagePath = "$($SolutionDirectory)/packages/Remotion.BuildTools.MSBuildTasks.$($BuildToolsVersion)/lib/net45/"
    $RestPackagePath = "$($SolutionDirectory)/packages/Remotion.BuildTools.MSBuildTasks.$($BuildToolsVersion)/tools/"

    Load-Dll (Join-Path $BuildToolsPackagePath "Remotion.BuildTools.MSBuildTasks.dll") > $NULL
    Load-Dll (Join-Path $RestPackagePath "RestSharp.dll") > $NULL
}

function Load-Dll ($Path)
{

    #Load Dll as bytestream so file does not get locked
    $FileStream = ([System.IO.FileInfo] (Get-Item $Path)).OpenRead()
    $AssemblyBytes = New-Object byte[] $FileStream.Length
    $FileStream.Read($AssemblyBytes, 0, $FileStream.Length)
    $FileStream.Close()

    $AssemblyLoaded = [System.Reflection.Assembly]::Load($AssemblyBytes)
}