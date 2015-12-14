$Location = $PSScriptRoot

function Load-Dependency-Dll ()
{
    
    $SolutionDirectory = git rev-parse --show-toplevel
    #$package = Get-Package -Filter -"Remotion.BuildTools.MSBuildTasks"
    #Todo: Remove Hardcoded path
    $PackagePath = "$($SolutionDirectory)/packages/Remotion.BuildTools.MSBuildTasks.1.0.5745.12485/tools/"

    Load-Dll (Join-Path $PackagePath "Remotion.BuildTools.MSBuildTasks.dll") > $NULL
    Load-Dll (Join-Path $PackagePath "RestSharp.dll") > $NULL
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