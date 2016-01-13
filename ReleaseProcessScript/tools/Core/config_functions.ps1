[xml]$global:ConfigFile = $NULL

function Get-Config-File ()
{
    $ConfigFilePath = Get-Config-File-Path

    if ([string]::IsNullOrEmpty($ConfigFilePath))
    {
      if ($global:ConfigFile -eq $NULL)
      {
        throw "Config file not found."
      } 
      else
      {
        #We cant find the Config file but it got set before, so we return our Cached variable (in case we are on a branch which does not have ReleaseProcessScript installed)
        return $global:ConfigFile
      }
    }

    if (-not (Test-Path $ConfigFilePath))
    {
      throw "Config file not found."
    }
    
    $global:ConfigFile = Get-Content $ConfigFilePath

    return $global:ConfigFile 
}

function Get-Config-File-Path ()
{
    $TopLevelPath = git rev-parse --show-toplevel 2>&1
    $MarkerFile = Get-Marker-File

    return (Join-path $TopLevelPath $MarkerFile.configFile.path)
}

function Get-Marker-File ()
{
    $TopLevelPath = git rev-parse --show-toplevel 2>&1
    $MarkerName = ".BuildProject"

    $MarkerPath = Join-Path $TopLevelPath $MarkerName

    if (-not (Test-Path $MarkerPath) )
    {
      if (-not $global:ConfigFile)
      {
        throw ".BuildProject not found. Please reinstall package or add .BuildProject again."
      }
      else
      {
        return $NULL
      }
    }

    return [xml]$MarkerFile = Get-Content $MarkerPath
}

function Config-Use-NTLM
{
    $ConfigFile = Get-Config-File
    $UseNTLM = $ConfigFile.jira.useNTLM

    if ( ($UseNTLM.ToUpper -eq "YES") -or ($UseNTLM.ToUpper -eq "Y") -or ($UseNTLM.ToUpper -eq "T") -or ($UseNTLM.ToUpper -eq "TRUE") )
    {
      return $TRUE
    }
    else
    {
      return $FALSE
    }
    
    return $FALSE 
}