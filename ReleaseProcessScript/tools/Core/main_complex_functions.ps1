

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