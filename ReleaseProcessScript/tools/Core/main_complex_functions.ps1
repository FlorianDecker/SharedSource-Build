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
        $Argument -replace "{version}", $CurrentVersion

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
        
        git add -A 2>&1
        git commit -m $CommitMessage 2>&1
        Resolve-Merge-Conflicts       
      }      
    }
}


function Create-Tag-And-Merge ()
{
    Check-Is-On-Branch "release/"
    
    $CurrentBranchname = Get-Current-Branchname
    $CurrentVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname

    Check-Branch-Up-To-Date $CurrentBranchname
    Check-Branch-Exists-And-Up-To-Date "master"
    Check-Branch-Exists-And-Up-To-Date "develop"
  
    if (Get-Tag-Exists "v$($CurrentVersion)")
    {
      throw "There is already a commit tagged with 'v$($CurrentVersion)'."
    }
    
    git checkout "master" 2>&1 > $NULL
    
    git merge $CurrentBranchname --no-ff 2>&1
    
    Resolve-Merge-Conflicts

    Check-Branch-Up-To-Date "develop"
    
    Merge-Branch-With-Reset "develop" $CurrentBranchname "developStableMergeIgnoreList"

    git checkout master 2>&1 > $NULL
    git tag -a "v$($CurrentVersion)" -m "v$($currentVersion)" 2>&1 > $NULL
    
    git checkout develop 2>&1 | Write-Host
}

function Push-Master-Release ($Version)
{
    $Branchname = "release/v$($Version)"

    if (-not (Get-Branch-Exists $Branchname) )
    {
      throw "The branch '$($Branchname)' does not exist. Please create a release branch first."
    }

    Check-Branch-Up-To-Date $Branchname
    Push-To-Repos $Branchname

    Check-Branch-Up-To-Date "master"

    Check-Branch-Up-To-Date "develop"
    Push-To-Repos "master" $TRUE
    Push-To-Repos "develop"
}

function Restore-Packages ()
{
    try
    {
      & nuget.exe restore
    }
    catch
    {
      Write-Error "Could not restore nuget packages."
    }
}