function Parse-Version-From-ReleaseBranch ($Branchname){
    $SplitBranchname = $Branchname.Split("/v")

    if ($SplitBranchname.Length -ne 3)
    {
      throw "Current branch name is not in a valid format (e.g. release/v1.2.3)."
    }
    
    return $SplitBranchname[2]
}

function Create-And-Release-Jira-Versions ($CurrentVersion, $NextVersion, $SquashUnreleased)
{
    $CurrentVersionId = Jira-Create-Version $CurrentVersion
    $NextVersionId = Jira-Create-Version $NextVersion

    Write-Host "Releasing version '$($CurrentVersion) on JIRA."
    Write-Host "Moving open issues to '$($NextVersion)'."

    Jira-Release-Version $CurrentVersionId $NextVersionId $SquashUnreleased
}

function Get-Develop-Current-Version ($StartReleasebranch)
{
    if ($StartReleasebranch)
    {
      $WithoutPrerelease = $TRUE
    }
    else
    {
      $WithoutPrerelease = $FALSE
    }

    #Get last Tag from develop
    $DevelopVersion = Get-Last-Version-Of-Branch-From-Tag

    #Get last Tag from master (because Get-Last-Version-Of-Branch-From-Tag does not reach master, so the master commit could be the most recent)
    $MasterVersion = Get-Last-Version-Of-Branch-From-Tag "master"


    #Take most recent
    $MostRecentVersion = Get-Most-Recent-Version $DevelopVersion.Substring(1) $MasterVersion.Substring(1)
    
    $PossibleVersions = Get-Possible-Next-Versions-Develop $MostRecentVersion $WithoutPrerelease

    $CurrentVersion = Read-Version-Choice $PossibleVersions

    return $CurrentVersion
}

function Get-Support-Current-Version ($SupportVersion, $StartReleasePhase)
{
    if (-not (Get-Tag-Exists "v$($SupportVersion).0") )
    {
      $CurrentVersion = "$($SupportVersion).0"
    }
    else
    {
      $LastVersion = Get-Last-Version-Of-Branch-From-Tag
     
      if ($StartReleasePhase)
      {
        $CurrentVersion = Get-Next-Patch $LastVersion.Substring(1)
      }
      else
      {
        $PossibleVersions = Get-Possible-Next-Versions-Support $LastVersion.Substring(1)
        $CurrentVersion = Read-Version-Choice $PossibleVersions
      }
    }

    return $CurrentVersion
}

function Reset-Items-Of-Ignore-List ()
{
    param
    (
      [string]$ListToBeIgnored
    )

    $ConfigFile = Get-Config-File

    $IgnoredFiles = ""
        
    if ($ListToBeIgnored -eq "prereleaseMergeIgnoreList")
    {
      $IgnoredFiles = $ConfigFile.settings.prereleaseMergeIgnoreList.fileName
    }
    elseif ($ListToBeIgnored -eq "tagStableMergeIgnoreList")
    {
      $IgnoredFiles = $ConfigFile.settings.tagStableMergeIgnoreList.fileName
    }
    elseif ($ListToBeIgnored -eq "developStableMergeIgnoreList")
    {
      $IgnoredFiles = $ConfigFile.settings.developStableMergeIgnoreList.fileName
    }

    foreach ($File in $IgnoredFiles)
    {
      if (-Not [string]::IsNullOrEmpty($File) )
      {
        git reset HEAD $File
        git checkout -- $File
      }
    }
}

function Merge-Branch-With-Reset ($CurrentBranchname, $MergeBranchname, $IgnoreList)
{
    git checkout $CurrentBranchname --quiet
    git merge $MergeBranchname --no-ff --no-commit 2>&1 | Write-Host
    Reset-Items-Of-Ignore-List -ListToBeIgnored $IgnoreList
    git commit -m "Merge branch '$($MergeBranchname)' into $($CurrentBranchName)" 2>&1 | Write-Host
    Resolve-Merge-Conflicts
}

function Find-Next-Rc ($CurrentVersion)
{
  $NextRc = Get-Next-Rc $CurrentVersion

  while (Get-Tag-Exists ("v$($NextRc)") )
  {
    $NextRc = Get-Next-Rc $NextRc
  }

  return $NextRc
}