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

function Get-Develop-Current-Version ()
{
    #Get last Tag from develop
    $DevelopVersion = Get-Last-Version-Of-Branch-From-Tag

    #Get last Tag from master (because Get-Last-Version-Of-Branch-From-Tag does not reach master, so the master commit could be the recent)
    $MasterVersion = Get-Last-Version-Of-Branch-From-Tag "master"

    #Take most recent
    if ($DevelopVersion.CompareTo($MasterVersion) -eq 1)
    {
      $LastVersion = $DevelopVersion
    }
    else
    {
      $LastVersion = $MasterVersion
    }
    
    $PossibleVersions = Get-Possible-Next-Versions-Develop $LastVersion.Substring(1)

    $CurrentVersion = Read-Version-Choice $PossibleVersions

    return $CurrentVersion
}

function Get-Support-Current-Version ($SupportVersion)
{
    if (-not (Get-Tag-Exists "v$($SupportVersion).0") )
    {
      $CurrentVersion = "$($SupportVersion).0"
    }
    else
    {
     $LastVersion = Get-Last-Version-Of-Branch-From-Tag
     $PossibleVersions = Get-Possible-Next-Versions-Support $LastVersion.Substring(1)
     $CurrentVersion = Read-Version-Choice $PossibleVersions
    }

    return $CurrentVersion
}

function Check-Is-On-Branch ($Branchname)
{
    if (-not (Is-On-Branch $Branchname) )
    {
      throw "You have to be on '$($Branchname)' branch for this operation."
    }
}

function Check-Branch-Does-Not-Exists ($Branchname)
{
    if (Get-Branch-Exists $Branchname)
    {
      throw "The branch '$($Branchname)' already exists."
    }
}

function Check-Branch-Exists-And-Up-To-Date ($Branchname)
{
    if (-not (Get-Branch-Exists $Branchname) )
    {
      throw "'$($Branchname)' does not exist. Please ensure its existence before proceeding."
    }

    Check-Branch-Up-To-Date $Branchname
}

function Check-Working-Directory ()
{
    if (-not (Is-Working-Directory-Clean) )
    {
      $WantsToContinue = Read-Continue

      if (-not $WantsToContinue)
      {
        throw "Release process stopped."
      }
    }
}