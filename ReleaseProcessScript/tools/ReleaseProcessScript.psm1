$Location = $PSScriptRoot

. $Location"\Core\main_functions.ps1"


function New-Version ()
{
  <#
  .SYNOPSIS
  Releases a new Version

  .DESCRIPTION
  New-Version determines which Release the User want to perform based on the position of the git HEAD and additional User input.
  It then releases the Version on Jira, creates the Release Branch, Invokes MsBuild Scripts and finally does a Merge, Tag and Push as defined in the Git Flow Model. 

  .PARAMETER CommitHash 
  Optional Parameter which defines on which CommitHash you want the ReleaseBranch to start

  .PARAMETER PauseForCommit
  Optional <switch> Parameter. If given, the scripts stops before merging or tagging the release branch. The User may continue afterwards with 'Complete-Version'

  .PARAMETER PauseForCommit
  Optional <switch> Parameter. If given, the scripts stops before pushing the changes to the remote repositories
  #>

  [CmdletBinding()]
  param
  (
    [string] $CommitHash,
    [switch] $PauseForCommit,
    [switch] $DoNotPush
  )

  Release-Version -CommitHash:$CommitHash -PauseForCommit:$PauseForCommit -DoNotPush:$DoNotPush
}

function New-Releasebranch ()
{
  <#
  .SYNOPSIS
  Creates a new release Branch

  .DESCRIPTION
  Determines the release Version and only creates the release Branch and invokes the Ms Builds for DevelopmentForNextRelease

  .PARAMETER CommitHash 
  Optional Parameter which defines on which CommitHash you want the ReleaseBranch to start

  .Note
  Does not work for prerelease branches
  #>

  [CmdletBinding()]
  param
  (
    [string] $CommitHash
  )

  Release-Version -StartReleasePhase -CommitHash:$CommitHash
}

function Close-Version ()
{
  <#
  .SYNOPSIS
  Completes the Version Process

  .DESCRIPTION
  If you invoked New-Version -PauseForCommit or created the Release Branch yourselve, this command continues with Merge, Tag and Push

  .PARAMETER DoNotPush
  Optional <switch> Parameter. If given, the scripts stops before pushing the changes to the remote repositories

  .PARAMETER Ancestor
  The script cant always determine from which branch the release branch emerged from. If you give him the parameter now, the script does not have to ask later.
  #>

  [CmdletBinding()]
  param
  (
    [switch] $DoNotPush, 
    [string] $Ancestor  
  )

  Continue-Release -DoNotPush:$DoNotPush -Ancestor $Ancestor
}

function Push-Remote-Repositories ()
{
  <#
  .SYNOPSIS
  Push given Branchname to Remote Repositories defined in releaseProcessScript.config

  .DESCRIPTION
  Push given Branchname to the Remote Repositories defined in releaseProcessScript.config

  .PARAMETER Branchname
  Mandatory string Parameter. Defines which branch to push

  .PARAMETER WithTags
  Optional <switch> Parameter. If given, tags on the branch also get pushed

  .NOTE
  If the Branch has no tracking branch on a remote configured, the remote takes the remote tracking reference defined for the ancestor branch.
  #>

  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$true)]
    [string]$Branchname, 
    [switch]$WithTags
  )

  Push-To-Repos $Branchname $WithTags
}

Export-ModuleMember -Function New-Version
Export-ModuleMember -Function New-Releasebranch
Export-ModuleMember -Function Close-Version
Export-ModuleMember -Function Push-Remote-Repositories