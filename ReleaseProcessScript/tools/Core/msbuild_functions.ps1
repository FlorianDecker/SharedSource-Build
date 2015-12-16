function Invoke-MsBuild-And-Commit ()
{
    param 
    (
      [string]$CurrentVersion, 
      [string]$MsBuildMode
    )


    $Config = Get-Config-File

    $MsBuildPath = $Config.settings.msBuildSettings.msBuildPath
    
    if ($MsBuildMode -eq "prepareNextVersion")
    {
      $MsBuildSteps = $Config.settings.prepareNextVersionMsBuildSteps.step
    }
    elseif ($MsBuildMode -eq "developmentForNextRelease")
    {
      $MsBuildSteps = $Config.settings.developmentForNextReleaseMsBuildSteps.step  
    }
    else
    {
      Write-Error "Invalid Parameter in Invoke-Ms-Build-And-Commit. No MsBuildStepsCompleted. Please check if -MsBuildMode parameter is equivalent with the value in releaseProcessScript.config"
    }

    if ([string]::IsNullOrEmpty($MsBuildPath) )
    {
      return
    }

    Restore-Packages

    foreach ($Step in $MsBuildSteps)
    {
      $CommitMessage = $Step.commitMessage
      $MsBuildCallArray = @()

      if (-not [string]::IsNullOrEmpty($CommitMessage) )
      {
        if (-not (Is-Working-Directory-Clean) )
        {
          throw "Working directory has to be clean for a call to MsBuild.exe with commit message defined in config."
        }
      }
      
      foreach ($Argument in $Step.msBuildCallArguments.argument)
      {
        $Argument = $Argument -replace "{version}", $CurrentVersion
        $Argument = $Argument -replace "{Version}", $CurrentVersion

        $MsBuildCallArray += $Argument
      }
      
      Write-Host "Starting $($MsBuildPath) $($MsBuildCallArray)"
      

      & $MsBuildPath $MsBuildCallArray
      
      if ($?)
      {
        Write-Host "Successfully called '$($MsBuildPath) $($MsBuildCallArray)'."
      } 
      else
      {
        throw "$($MsBuildPath) $($MsBuildCallArray) failed with Error Code '$($LASTEXITCODE)'."
      }

      if ([string]::IsNullOrEmpty($CommitMessage) )
      {
        if (-not (Is-Working-Directory-Clean) )
        {
          throw "Working directory has to be clean after a call to MsBuild.exe without a commit message defined in config."
        }
      } 
      else
      {
        $CommitMessage = $CommitMessage -replace "{version}", $CurrentVersion
        $CommitMessage = $CommitMessage -replace "{Version}", $CurrentVersion
        
        git add -A 2>&1 | Write-Host
        git commit -m $CommitMessage 2>&1 | Write-Host
        Resolve-Merge-Conflicts       
      }      
    }
}
