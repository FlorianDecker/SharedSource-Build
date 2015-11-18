$Location = $PSScriptRoot

. $Location"\git_base_functions.ps1"
. $Location"\config_functions.ps1"
. $Location"\jira_functions.ps1"
. $Location"\semver_functions.ps1" 
. $Location"\main_helper_functions.ps1"
. $Location"\main_complex_functions.ps1"
. $Location"\read_functions.ps1"

function Release-Version ()
{
    [CmdletBinding()]
    param
    (
      [string] $CommitHash,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Commit-Hash $CommitHash

    $CurrentBranchname = Get-Current-Branchname

    if (Is-On-Branch "support/")
    {
      $SupportVersion = $CurrentBranchname.Split("/")[1]
      $CurrentVersion = Get-Support-Current-Version $SupportVersion
      $PreVersion = Get-PreReleaseStage $CurrentVersion

      if ([string]::IsNullOrEmpty($PreVersion))
      {
        Release-Support -StartReleasePhase:$StartReleasePhase -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
      elseif ( ($PreVersion -eq "alpha") -or ($PreVersion -eq "beta") )
      {
        Release-Alpha-Beta -CurrentVersion $CurrentVersion -StartReleasePhase:$StartReleasePhase -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
    } 
    elseif (Is-On-Branch "develop")
    {
      $CurrentVersion = Get-Develop-Current-Version
      $PreVersion = Get-PreReleaseStage $CurrentVersion

      if ([string]::IsNullOrEmpty($PreVersion))
      {
        Release-On-Master -CurrentVersion $CurrentVersion -StartReleasePhase:$StartReleasePhase -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
      elseif ( ($PreVersion -eq "alpha") -or ($PreVersion -eq "beta"))
      {
        Release-Alpha-Beta -CurrentVersion $CurrentVersion -StartReleasePhase:$StartReleasePhase -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
    }
    elseif (Is-On-Branch "release/")
    {
      $CurrentVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname
      $RcVersion = Get-Next-Rc $CurrentVersion

      Write-Host "Do you want to release '$($RcVersion)' [1] or current version '$($CurrentVersion)' [2] ?"

      $ReleaseChoice = Read-Release-Branch-Mode-Choice

      if ($ReleaseChoice -eq 1)
      {
        Release-RC -StartReleasePhase:$StartReleasePhase -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
      elseif ($ReleaseChoice -eq 2)
      {
        Release-With-RC -StartReleasePhase:$StartReleasePhase -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush
      } 
    }
    else
    {
      throw "You have to be on either a 'support/*' or 'release/*' or 'develop' branch to release a version."
    }
}

function Continue-Release()
{
    [CmdletBinding()]
    param
    (
       [switch] $DoNotPush   
    )

    $CurrentBranchname = Get-Current-Branchname
    $CurrentVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname

    if ( Is-On-Branch "prerelease/" )
    {
      Continue-Pre-Release $CurrentVersion -DoNotPush:$DoNotPush
    }
    elseif (Is-On-Branch "release/")
    {
      if (Is-Support-Version $CurrentVersion)
      {
        Continue-Support-Release $CurrentVersion -DoNotPush:$DoNotPush
      } 
      else
      {
        Continue-Master-Release $CurrentVersion -DoNotPush:$DoNotPush
      }    
    }
    else
    {
      throw "You have to be on a prerelease/* or release/* branch to continue a release."
    }
}

function Release-Support ()
{
    [CmdletBinding()]
    param
    (
      [string] $CommitHash,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )
    
    Check-Working-Directory
    Check-Commit-Hash $CommitHash
    Check-Is-On-Branch "support/"

    $CurrentBranchname = Get-Current-Branchname

    $LastVersion = (Get-Last-Version-Of-Branch-From-Tag).substring(1)
    
    #No Tags on this branch? Our Last Version Patch = 0, so Current Version then has Patch = 1
    if ([string]::IsNullOrEmpty($LastVersion))
    {
      $SupportBranchVersion = ($CurrentBranchname).Split("/")[1].Substring(1)
      $LastVersion = "$($SupportBranchVersion).0"
    }

    $CurrentVersion = Get-Next-Patch $LastVersion
    Write-Host "Current version: '$($CurrentVersion)'."
    $NextVersion = Get-Next-Patch $CurrentVersion  
    Write-Host "Next version: '$($NextVersion)'."

    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion

    $ReleaseBranchname = "release/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists $ReleaseBranchname
    
    git checkout $CommitHash -b $ReleaseBranchname 2>&1 | Write-Host

    if ($StartReleasePhase)
    {
      Call-MsBuild-And-Commit -CurrentVersion $CurrentVersion
    }

    if ($PauseForCommit)
    {
      return
    }

    Continue-Support-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
}

function Release-On-Master ()
{
    [CmdletBinding()]
    param
    (
      [string] $CommitHash,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush,
      [string] $CurrentVersion
    )

    Check-Working-Directory
    Check-Commit-Hash $CommitHash

    $CurrentBranchname = Get-Current-Branchname
    Check-Is-On-Branch "develop"

    if ([string]::IsNullOrEmpty($CurrentVersion) )
    {
      $CurrentVersion = Get-Develop-Current-Version
    }

    $ReleaseBranchname = "release/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists $ReleaseBranchname

    $NextPossibleVersions = Get-Possible-Next-Versions $CurrentVersion
    Write-Host "Please choose next version (open JIRA issues get moved there): "
    $NextVersion = Read-Version-Choice $NextPossibleVersions

    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion

    git checkout $CommitHash -b $ReleaseBranchname 2>&1 | Write-Host
    
    if ($StartReleasePhase)
    {
      return
    }
    
    Invoke-MsBuild-And-Commit -CurrentVersion $CurrentVersion

    if ($PauseForCommit)
    {
      return
    }
      
    Continue-Master-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
}

function Release-Alpha-Beta ()
{
    [CmdletBinding()]
    param
    (
      [string] $CommitHash,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush,
      [string] $CurrentVersion
    )

    Check-Working-Directory
    Check-Commit-Hash $CommitHash

    if ([string]::IsNullOrEmpty($CurrentVersion) )
    {
      $VersionFromTag = Get-Last-Version-From-Tag-Not-On-Support

      if ([string]::IsNullOrEmpty($VersionFromTag))
      {
        $CurrentVersion = Read-Host "No version found. Please enter a release version: "
      } 
      else
      {
        $LastVersion = $VersionFromTag.substring(1)
        $CurrentVersion = Get-Next-AlphaBeta $LastVersion
      }
    }

    if (Is-Support-Version $CurrentVersion)
    {
      Check-Is-On-Branch "support/"
    }
    else
    {
      Check-Is-On-Branch "develop"
    }

    $NextPossibleVersions = Get-Possible-Next-Versions $CurrentVersion
    Write-Host "Please choose next version (open JIRA issues get moved there): "
    $NextVersion = Read-Version-Choice $NextPossibleVersions
   
    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion $TRUE
 
    $PreReleaseBranchname = "prerelease/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists $PreReleaseBranchname

    git checkout $CommitHash -b $PreReleaseBranchname 2>&1 | Write-Host

    if ($StartReleasePhase)
    {
      return
    }

    Invoke-MsBuild-And-Commit $CurrentVersion
        
    if ($PauseForCommit)
    {
      return
    }

    Continue-Pre-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
}

function Release-RC ()
{
    [CmdletBinding()]
    param
    (
      [string] $CommitHash,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Working-Directory
    Check-Commit-Hash $CommitHash
    Check-Is-On-Branch "release/"

    $CurrentBranchname = Get-Current-Branchname
    $LastVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname

    $CurrentVersion = Get-Next-Rc $LastVersion

    $NextPossibleVersions = Get-Possible-Next-Versions $CurrentVersion
    Write-Host "Please choose next version (open JIRA issues get moved there): "
    $NextVersion = Read-Version-Choice $NextPossibleVersions

    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion $TRUE

    $PreReleaseBranchname = "prerelease/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists
    
    git checkout $CommitHash -b $PreReleaseBranchname 2>&1 | Write-Host

    if ($StartReleasePhase)
    {
      return
    }

    Invoke-MsBuild-And-Commit $CurrentVersion
    
    if ($PauseForCommit)
    {
      return
    }

    Continue-Pre-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
}

function Release-With-RC ()
{
    [CmdletBinding()]
    param
    (
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Working-Directory
    Check-Is-On-Branch "release/"
    
    $CurrentBranchname = Get-Current-Branchname
    $CurrentVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname
    
    if (Get-Tag-Exists "v$($CurrentVersion)")
    {
      throw "There is already a commit tagged with 'v$($CurrentVersion)'."
    }

    Write-Host "You are releasing version '$($CurrentVersion)'."
    $PossibleNextVersions = Get-Possible-Next-Versions $CurrentVersion
    Write-Host "Choose next version (open issues get moved there): "
    $NextVersion = Read-Version-Choice $PossibleNextVersions
    
    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion

    if ($StartReleasePhase)
    {
      return
    }

    Invoke-MsBuild-And-Commit $CurrentVersion

    if ($PauseForCommit)
    {
      return
    }

    if (Is-Support-Version $CurrentVersion)
    {
      Continue-Support-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
    }
    else
    {
      Continue-Master-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
    }
}

function Continue-Support-Release ()
{
    [CmdletBinding()]
    param
    (
       [string] $CurrentVersion,
       [switch] $DoNotPush   
    )

    Check-Working-Directory

    $MajorMinor = Get-Major-Minor-From-Version $CurrentVersion
    $SupportBranchname = "support/v$($MajorMinor)"
    
    Check-Branch-Up-To-Date $SupportBranchname
    Check-Branch-Up-To-Date "release/v$($CurrentVersion)"

    $Tagname = "v$($CurrentVersion)"

    if (Get-Tag-Exists $Tagname)
    {
      throw "Tag '$($Tagname)' already exists." 
    }

    git checkout $SupportBranchname --quiet

    git merge "release/v$($CurrentVersion)" --no-ff 2>&1
    
    git tag -a $Tagname -m $Tagname 2>&1

    if ($DoNotPush)
    {
      return
    }

    Push-To-Repos $SupportBranchname $TRUE
    Push-To-Repos "release/v$($CurrentVersion)"
}

function Continue-Master-Release ()
{
    [CmdletBinding()]
    param
    (
       [string] $CurrentVersion,
       [switch] $DoNotPush   
    )

    $CurrentBranchname = Get-Current-Branchname

    Check-Working-Directory

    Check-Branch-Exists-And-Up-To-Date "master"
    Check-Branch-Exists-And-Up-To-Date "develop"

    git checkout $CurrentBranchname --quiet

    Create-Tag-And-Merge
    
    if ($DoNotPush)
    {
      return
    }

    Push-Master-Release $CurrentVersion
}

function Continue-Pre-Release ()
{
    [CmdletBinding()]
    param
    (
       [string] $CurrentVersion,
       [switch] $DoNotPush   
    )

    Check-Working-Directory
    Check-Is-On-Branch "prerelease/"
    $CurrentBranchname = Get-Current-Branchname
    $Tagname = "v$($CurrentVersion)"

    Check-Branch-Up-To-Date $CurrentBranchname

    if (Get-Tag-Exists $Tagname)
    {
      throw "Tag '$($Tagname)' already exists." 
    }

    git tag -a "$($Tagname)" -m "$($Tagname)" 2>&1 > $NULL    

    if (Is-Support-Version $CurrentVersion)
    {
      $MajorMinor = Get-Major-Minor-From-Version $CurrentVersion
      $MergeBranchName = "support/v$($MajorMinor)"
    }
    else
    {
      $MergeBranchName = "develop"
    }

    Check-Branch-Exists-And-Up-To-Date $MergeBranchName
    
    git merge $CurrentBranchname --no-ff --no-commit 2>&1 | Write-Host
    
    $ConfigFile = Get-Config-File

    foreach ($File in $ConfigFile.settings.mergeExcludedFiles.fileName)
    {
      if (-Not [string]::IsNullOrEmpty($File) )
      {
        git reset HEAD $File
        git checkout -- $File
      }
    }
     
    git commit -m "Merge branch '$($CurrentBranchname)' into $($MergeBranchName)" 2>&1 | Write-Host

    Resolve-Merge-Conflicts
      

    if ($DoNotPush)
    {
      return
    }

    Push-To-Repos $MergeBranchName
    Push-To-Repos $CurrentBranchname $TRUE
}

Export-ModuleMember -Function *