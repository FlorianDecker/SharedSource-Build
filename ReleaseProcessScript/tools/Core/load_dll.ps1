$Location = $PSScriptRoot

function Get-Dll ($Path)
{
    #Load Dll as bytestream so file does not get locked
    $FileStream = ([System.IO.FileInfo] (Get-Item $Path)).OpenRead()
    $AssemblyBytes = New-Object byte[] $FileStream.Length
    $FileStream.Read($AssemblyBytes, 0, $FileStream.Length)
    $FileStream.Close()

    $AssemblyLoaded = [System.Reflection.Assembly]::Load($AssemblyBytes)
}

Get-Dll $Location"\..\..\lib\RestSharp.dll" > $NULL
Get-Dll $Location"\..\..\lib\Remotion.BuildTools.MSBuildTasks.dll" > $NULL