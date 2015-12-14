$Location = $PSScriptRoot

. $Location"\git_base_functions.ps1"
. $Location"\config_functions.ps1"
. $Location"\jira_functions.ps1"
. $Location"\semver_functions.ps1" 
. $Location"\main_helper_functions.ps1"
. $Location"\main_complex_functions.ps1"
. $Location"\read_functions.ps1"
. $Location"\check_functions.ps1"

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
      $SupportVersion = $CurrentBranchname.Split("/")[1].Substring(1)
      $CurrentVersion = Get-Support-Current-Version $SupportVersion
      $PreVersion = Get-PreReleaseStage $CurrentVersion

      if ([string]::IsNullOrEmpty($PreVersion))
      {
        Release-Support -StartReleasePhase:$StartReleasePhase -CurrentVersion $CurrentVersion -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
      elseif ( ($PreVersion -eq "alpha") -or ($PreVersion -eq "beta") )
      {
        Release-Alpha-Beta -CurrentVersion $CurrentVersion -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
    } 
    elseif (Is-On-Branch "develop")
    {
      $CurrentVersion = Get-Develop-Current-Version
      $PreVersion = Get-PreReleaseStage $CurrentVersion

      if ([string]::IsNullOrEmpty($PreVersion))
      {
        Release-On-Master -StartReleasePhase:$StartReleasePhase -CurrentVersion $CurrentVersion -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
      elseif ( ($PreVersion -eq "alpha") -or ($PreVersion -eq "beta"))
      {
        Release-Alpha-Beta -CurrentVersion $CurrentVersion -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
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
        Release-RC -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush -CommitHash $CommitHash
      }
      elseif ($ReleaseChoice -eq 2)
      {
        Release-With-RC -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush
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
      $Ancestor = Get-Ancestor

      if ($Ancestor -eq "develop" )
      {
        Continue-Master-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
      } 
      else
      {
        Continue-Support-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
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
      [Parameter(Mandatory=$true)]
      [string] $CurrentVersion,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )
    
    Check-Working-Directory
    Check-Commit-Hash $CommitHash
    Check-Is-On-Branch "support/"

    $CurrentBranchname = Get-Current-Branchname

    Write-Host "Current version: '$($CurrentVersion)'."
    $NextVersion = Get-Next-Patch $CurrentVersion  
    Write-Host "Next version: '$($NextVersion)'."

    $ReleaseBranchname = "release/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists $ReleaseBranchname
    
    Invoke-MsBuild-And-Commit -CurrentVersion $CurrentVersion -MsBuildMode "developmentForNextRelease"

    git checkout $CommitHash -b $ReleaseBranchname 2>&1 | Write-Host

    if ($StartReleasePhase)
    {
      return
    }

    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion 
    
    Invoke-MsBuild-And-Commit -CurrentVersion $CurrentVersion -MsBuildMode "prepareNextVersion" 

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
      [Parameter(Mandatory=$true)]
      [string] $CurrentVersion,
      [switch] $StartReleasePhase,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Working-Directory
    Check-Commit-Hash $CommitHash

    $CurrentBranchname = Get-Current-Branchname
    Check-Is-On-Branch "develop"

    $ReleaseBranchname = "release/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists $ReleaseBranchname
    
    Invoke-MsBuild-And-Commit -CurrentVersion $CurrentVersion -MsBuildMode "developmentForNextRelease"
     
    git checkout $CommitHash -b $ReleaseBranchname 2>&1 | Write-Host
    
    if ($StartReleasePhase)
    {
      return
    }

    $NextPossibleVersions = Get-Possible-Next-Versions-Develop $CurrentVersion
    Write-Host "Please choose next version (open JIRA issues get moved there): "
    $NextVersion = Read-Version-Choice $NextPossibleVersions

    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion
    
    Invoke-MsBuild-And-Commit -CurrentVersion $CurrentVersion -MsBuildMode "prepareNextVersion" 

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
      [Parameter(Mandatory=$true)]
      [string] $CurrentVersion,
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Working-Directory
    Check-Commit-Hash $CommitHash

    $CurrentBranchname = Get-Current-Branchname

    if ($CurrentBranchname.StartsWith("support/"))
    {
      $NextPossibleVersions = Get-Possible-Next-Versions-Support $CurrentVersion
    }
    elseif ($CurrentBranchname -eq "develop")
    {
      $NextPossibleVersions = Get-Possible-Next-Versions-Develop $CurrentVersion
    }
    else
    {
      throw "You have to be on either a 'support/*' branch or on 'develop' to release an alpha or beta version"
    }

    $PreReleaseBranchname = "prerelease/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists $PreReleaseBranchname

    git checkout $CommitHash -b $PreReleaseBranchname 2>&1 | Write-Host

    Write-Host "Please choose next version (open JIRA issues get moved there): "
    $NextVersion = Read-Version-Choice $NextPossibleVersions
   
    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion $TRUE

    Invoke-MsBuild-And-Commit $CurrentVersion -MsBuildMode "prepareNextVersion" 
        
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
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Working-Directory
    Check-Commit-Hash $CommitHash
    Check-Is-On-Branch "release/"
    $Ancestor = Get-Ancestor

    $CurrentBranchname = Get-Current-Branchname
    $LastVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname

    $CurrentVersion = Get-Next-Rc $LastVersion

    if ($Ancestor -eq "develop")
    {
      $NextPossibleVersions = Get-Possible-Next-Versions-Develop $CurrentVersion
    }
    else
    {
      $NextPossibleVersions = Get-Possible-Next-Versions-Support $CurrentVersion
    }

    Write-Host "Please choose next version (open JIRA issues get moved there): "
    $NextVersion = Read-Version-Choice $NextPossibleVersions

    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion $TRUE

    $PreReleaseBranchname = "prerelease/v$($CurrentVersion)"
    Check-Branch-Does-Not-Exists
    
    git checkout $CommitHash -b $PreReleaseBranchname 2>&1 | Write-Host

    Invoke-MsBuild-And-Commit $CurrentVersion -MsBuildMode "prepareNextVersion" 
    
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
      [switch] $PauseForCommit,
      [switch] $DoNotPush
    )

    Check-Working-Directory
    Check-Is-On-Branch "release/"
    
    $CurrentBranchname = Get-Current-Branchname
    $CurrentVersion = Parse-Version-From-ReleaseBranch $CurrentBranchname
    $Ancestor = Get-Ancestor

    if (Get-Tag-Exists "v$($CurrentVersion)")
    {
      throw "There is already a commit tagged with 'v$($CurrentVersion)'."
    }

    Write-Host "You are releasing version '$($CurrentVersion)'."
    
    if ($Ancestor -eq "develop")
    {
      $PossibleNextVersions = Get-Possible-Next-Versions-Develop $CurrentVersion
    }
    else
    {
      $PossibleNextVersions = Get-Possible-Next-Versions-Support $CurrentVersion
    }


    Write-Host "Choose next version (open issues get moved there): "
    $NextVersion = Read-Version-Choice $PossibleNextVersions
    
    Create-And-Release-Jira-Versions $CurrentVersion $NextVersion

    Invoke-MsBuild-And-Commit $CurrentVersion -MsBuildMode "prepareNextVersion" 

    if ($PauseForCommit)
    {
      return
    }

    
    if ($Ancestor -eq "develop")
    {
      Continue-Master-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
    }
    else
    {
      Continue-Support-Release -CurrentVersion $CurrentVersion -DoNotPush:$DoNotPush
    }
}

function Continue-Support-Release ()
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory=$true)]
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

    Merge-Branch-With-Reset $SupportBranchname "release/v$($CurrentVersion)" "tagStableMergeIgnoreList"

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
       [Parameter(Mandatory=$true)]
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
       [Parameter(Mandatory=$true)]
       [string] $CurrentVersion,
       [switch] $DoNotPush   
    )

    Check-Working-Directory
    Check-Is-On-Branch "prerelease/"
    $PrereleaseBranchname = Get-Current-Branchname
    $BaseVersion = Get-Version-Without-Pre $CurrentVersion
    $BaseBranchname = "release/v$($BaseVersion)"
    
    Check-Branch-Up-To-Date $PrereleaseBranchname
    Check-Branch-Up-To-Date $BaseBranchname
    
    $Tagname = "v$($CurrentVersion)"

    if (Get-Tag-Exists $Tagname)
    {
      throw "Tag '$($Tagname)' already exists." 
    }

    git tag -a "$($Tagname)" -m "$($Tagname)" 2>&1 > $NULL    

    Merge-Branch-With-Reset $BaseBranchname $PrereleaseBranchname "prereleaseMergeIgnoreList"
    
    if ($DoNotPush)
    {
      return
    }

    Push-To-Repos $MergeBranchName
    Push-To-Repos $CurrentBranchname $TRUE
}