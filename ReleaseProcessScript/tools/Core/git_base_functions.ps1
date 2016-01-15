. $PSScriptRoot"\config_functions.ps1"
. $PSScriptRoot"\semver_functions.ps1"

function Get-Branch-Exists ($Branchname)
{
    return (git show-ref --verify -- "refs/heads/$($Branchname)" 2>&1) -and $?
}

function Get-Branch-Exists-Remote ($RemoteName, $Branchname)
{
    return (git ls-remote --heads $RemoteName $Branchname 2>&1) -and $?
}

function Get-Tag-Exists ($Tagname)
{
    return (git show-ref --verify -- "refs/tags/$($Tagname)" 2>&1) -and $?
}

function Get-Current-Branchname ()
{
    return $(git symbolic-ref --short -q HEAD)
}

function Get-Last-Version-Of-Branch-From-Tag-Exists ($Branchname)
{
    return (git describe $Branchname --match "v[0-9]*" --abbrev=0 2>&1) -and $?
}

function Get-Last-Version-Of-Branch-From-Tag ($Branchname)
{
    return git describe $Branchname --match "v[0-9]*" --abbrev=0
}

function Is-On-Branch ($Branchname)
{
	$SymbolicRef = $(git symbolic-ref --short -q HEAD)

    if ($SymbolicRef -eq $Branchname)
    {
      return $TRUE
    }

    if ($Branchname.EndsWith("/") -and $SymbolicRef.StartsWith($Branchname))
    {
      return $TRUE
    } 

	return $FALSE
}

function Push-To-Repos ($Branchname, $WithTags)
{
    $BeforeBranchname = Get-Current-Branchname

    git checkout $Branchname 2>&1 --quiet

    if ($WithTags)
    {
      $PostFix = "--follow-tags"
    }

    $ConfigFile = Get-Config-File
    $RemoteNames = $ConfigFile.settings.remoteRepositories.remoteName
    $GitConfigRemotes = Get-Config-Remotes-Array

    foreach ($RemoteName in $RemoteNames)
    {
      if (-not [string]::IsNullOrEmpty($RemoteName) )
      {
        $SetUpstream = [string]::Empty

        $RemoteNameOfBranch = Get-Remote-Of-Branch $Branchname

        #Our Branch has no tracking reference defined (probably a new branch)
        if ([string]::IsNullOrEmpty($RemoteNameOfBranch) )
        {
          $WithoutAsking = $TRUE
          $Ancestor = Get-Ancestor $NULL $WithoutAsking

          $RemoteNameOfBranch = $NULL

          if ($Ancestor -ne $NULL)
          {
            $RemoteNameOfAncestor = Get-Remote-Of-Branch $Ancestor
          } 
          
          #And we also cant find an Ancestor with a tracking reference defined
          if ([string]::IsNullOrEmpty($RemoteNameOfAncestor) )
          {
            #If there is only one remote defined, we take that as tracking reference (count -eq 2 because they are saved as pairs)
            if ($GitConfigRemotes -and $GitConfigRemotes.Count -eq 2)
            {
              $RemoteName = $GitConfigRemotes[1]
            }
            else
            {
              Write-Host "No remote found for Branch. Please choose to which remote the Branch $($Branchname) should set its tracking reference: "
              
              #Build Array displaying "remotename  remoteurl" to choose from
              $DisplayGitConfigRemotes = for ($i = 0; $i -lt $GitConfigRemotes.count; $i += 2) { "$($GitConfigRemotes[$i].Split(".")[1]) $($GitConfigRemotes[$i + 1])" }
              
              #Read-Version-Choice returning "remotename remoteurl", split it to get remotename
              $RemoteName = (Read-Version-Choice  $DisplayGitConfigRemotes).Split()[0]
            }

            $SetUpstream = "-u"
            
          }
          elseif ($RemoteNameOfBranch -eq $RemoteName)
          {
             $SetUpstream = "-u"
          }
        } 

        & git push $SetUpstream $RemoteName $Branchname $PostFix 2>&1 | Write-Host
      }
    }
    
    git checkout $BeforeBranchname 2>&1 --quiet
}

function Get-Config-Remotes-Array ()
{
    #remote.<remotename>.url <remoteurl>
    $GitConfigRemoteUrls = git config --get-regexp remote.*.url
    $SplitGitConfigRemoteUrls = $NULL

    #Split entries into an array containing alternately remote.<remotename>.url and <remoteurl>
    if (-not [string]::IsNullOrEmpty($GitConfigRemoteUrls))
    {
      $SplitGitConfigRemoteUrls = $GitConfigRemoteUrls.Split().Split()
    }

    return $SplitGitConfigRemoteUrls
}

function Check-Branch-Up-To-Date($Branchname)
{
    git checkout $Branchname --quiet

    $ConfigFile = Get-Config-File
    $RemoteNames = $ConfigFile.settings.remoteRepositories.remoteName

    $GitConfigRemotes = Get-Config-Remotes-Array

    foreach ($RemoteName in $RemoteNames)
    {
      if (-not [string]::IsNullOrEmpty($RemoteName))
      {
        if (-Not (Get-Branch-Exists-Remote $Remotename $Branchname) )
        {
          continue 
        }

        git fetch $RemoteName $Branchname 2>&1 | Write-Host 

        $Local = $(git rev-parse $Branchname)
        $Remote = $(git rev-parse "$($RemoteName)/$($Branchname)")
        $Base = $(git merge-base $Branchname "$($RemoteName)/$($Branchname)")

        if ($Local -eq $Remote)
        {
          #Up-to-Date. OK
        } 
        elseif ($Local -eq $Base)
        {
          throw "Need to pull, local '$($Branchname)' branch is behind on repository '$($RemoteName)'."
        } 
        elseif ($Remote -eq $Base)
        {
          #Need to push, remote branch is behind. OK
        } 
        else
        {
          throw "'$($Branchname)' diverged, need to rebase at repository '$($RemoteName)'."
        }
      }
    }
}

function Check-Branch-Merged ($Branch, $PossiblyMergedBranchName)
{
    git checkout $Branch --quiet
    
    $MergedBranches = git branch --merged 2>&1 | Out-String
    
    if (-not [string]::IsNullOrEmpty($MergedBranches))
    {
      if ($MergedBranches -like $PossiblyMergedBranchName)
      {
        return $TRUE
      }
    }

    return $FALSE
}

function Resolve-Merge-Conflicts ()
{
    $MergeConflicts = git ls-files -u | git diff --name-only --diff-filter=U
    
    if (-not [string]::IsNullOrEmpty($MergeConflicts))
    {
      git mergetool $MergeConflicts
      git commit --file .git/MERGE_MSG
    }
}

function Is-Working-Directory-Clean ()
{
    $Status = git status --porcelain

    if ([string]::IsNullOrEmpty($Status))
    {
      return $TRUE
    } 
    else
    {
      return $FALSE
    }

    return $FALSE
}

function Get-Branch-From-Hash ($CommitHash)
{
    $Branches = git branch --contains $CommitHash

    $SplitBranches = $Branches.Split()

    if ($SplitBranches.Count -ne 2)
    {
      throw "Commit hash '$($CommitHash)' is contained in more than one branch or in none."
    }

    return $SplitBranches[1]
}

function Check-Commit-Hash ($CommitHash)
{
    if (-not $CommitHash)
    {
      return
    }

    $HashValidation = git cat-file -t $CommitHash

    if ($HashValidation -ne "commit")
    {
      throw "Given commit hash '$($CommitHash)' not found in repository."
    }
}

function Get-Remote-Of-Branch ($Branchname)
{
    return git config "branch.$($Branchname).remote"
}

function Get-Ancestor ($Branchname, $WithoutAsking)
{
  if ([string]::IsNullOrEmpty($Branchname))
  {
    $Branchname = Get-Current-Branchname
  }
  
  $Ancestor = git show-branch | where-object { $_.Contains('*') -eq $TRUE } | Where-object { $_.Contains($Branchname) -ne $TRUE } | select -first 1 | % {$_ -replace('.*\[(.*)\].*','$1')} | % { $_ -replace('[\^~].*','') }

  if ($Ancestor -eq $NULL)
  {
    return $NULL
  }

  if ( ($Ancestor -eq "develop") -or ($Ancestor.StartsWith("support/")) -or ($Ancestor -eq "master") )
  {
    return $Ancestor
  }
  elseif (-not $WithoutAsking)
  {
    Write-Host "Cannot determine ancestor of current release branch. Please enter the ancestor (develop, support/v*.*)."
    Write-Host "Ancestor: $($Ancestor)" 
    [string]$Ancestor = Read-Host "Pleace enter ancestor branchname"
    return $Ancestor
  }
  else
  {
    return $NULL
  }
}