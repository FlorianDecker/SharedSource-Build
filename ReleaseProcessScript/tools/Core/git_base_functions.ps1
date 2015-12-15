. $PSScriptRoot"\config_functions.ps1"
. $PSScriptRoot"\semver_functions.ps1"

function Get-Branch-Exists ($Branchname)
{
    return (git show-ref --verify -- "refs/heads/$($Branchname)" 2>&1) -and $?
}

function Get-Branch-Exists-Remote ($RemoteUrl, $Branchname)
{
    return (git ls-remote --heads $RemoteUrl $Branchname 2>&1) -and $?
}

function Get-Tag-Exists ($Tagname)
{
    return (git show-ref --verify -- "refs/tags/$($Tagname)" 2>&1) -and $?
}

function Get-Current-Branchname ()
{
    return $(git symbolic-ref --short -q HEAD)
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
    $RemoteUrls = $ConfigFile.settings.remoteRepositories
    $RemoteUrlArray = Get-Config-Remotes-Array

    foreach ($RemoteUrl in $RemoteUrls.remoteUrl)
    {
      if (-not [string]::IsNullOrEmpty($RemoteUrl) )
      {
        $SetUpstream = [string]::Empty

        $RemoteName = Get-Remote-Name-From-Url $RemoteUrlArray $RemoteUrl
        
        $RemoteNameOfBranch = Get-Remote-Of-Branch $Branchname

        if ([string]::IsNullOrEmpty($RemoteNameOfBranch) )
        {
          $Ancestor = Get-Ancestor
          $RemoteNameOfBranch = Get-Remote-Of-Branch $Ancestor

          if ([string]::IsNullOrEmpty($RemoteNameOfBranch) )
          {
            Write-Host "No remote found for Branch. Please choose to which remote the Branch $($Branchname) should set its tracking reference: "
            $RemoteName = Read-Version-Choice  $RemoteUrlArray
            & git push -u $RemoteName $Branchname $PostFix 2>&1 | Write-Host
            return
          }
          
          if ($RemoteNameOfBranch -eq $RemoteName)
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

    if (-not [string]::IsNullOrEmpty($GitConfigRemoteUrls))
    {
      $SplitGitConfigRemoteUrls = $GitConfigRemoteUrls.Split().Split(" ")    
    }

    return $SplitGitConfigRemoteUrls
}

function Get-Remote-Name-From-Url ($RemoteUrlArray, $RemoteUrl)
{
    if ($RemoteUrlArray  -eq $NULL)
    {
        throw "No Remotes found in .git config"
    }

    $FoundIndex = [array]::IndexOf($RemoteUrlArray , $RemoteUrl)

    if ($FoundIndex -eq -1)
    {
        throw "Remote url '$($RemoteUrl)' not found in .git config."
    }
        
    #FoundIndex-1 gives use the respective "remote.<remotename>.url" and we parse it for <remotename>
    return $RemoteUrlArray[$FoundIndex-1].Split(".")[1]
}

function Check-Branch-Up-To-Date($Branchname)
{
    git checkout $Branchname --quiet

    $ConfigFile = Get-Config-File
    $RemoteUrls = $ConfigFile.settings.remoteRepositories.remoteUrl

    $RemoteUrlArray = Get-Config-Remotes-Array

    foreach ($RemoteUrl in $RemoteUrls)
    {
      if (-not [string]::IsNullOrEmpty($RemoteUrl))
      {
        $RemoteName = Get-Remote-Name-From-Url $RemoteUrlArray $RemoteUrl

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
          throw "Need to pull, local '$($Branchname)' branch is behind on repository '$($RemoteUrl)'."
        } 
        elseif ($Remote -eq $Base)
        {
          #Need to push, remote branch is behind. OK
        } 
        else
        {
          throw "'$($Branchname)' diverged, need to rebase at repository '$($RemoteUrl)'."
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

function Get-Ancestor ($Branchname)
{
  if ([string]::IsNullOrEmpty($Branchname))
  {
    $Branchname = Get-Current-Branchname
  }
  
  return git show-branch | where-object { $_.Contains('!') -eq $TRUE } | Where-object { $_.Contains($Branchname) -ne $TRUE } | select -first 1 | % {$_ -replace('.*\[(.*)\].*','$1')} | % { $_ -replace('[\^~].*','') }

}