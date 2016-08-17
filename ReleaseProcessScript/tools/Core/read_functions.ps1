function Read-Choice-Of-Two ()
{
  while (!$ReleaseChoice)
  {
    $ReleaseChoice = Read-Host "Please enter 1 or 2 (0 for exit)"
  
    if ([string]::IsNullOrEmpty($ReleaseChoice))
    {
      return 1
    }
    elseif (($ReleaseChoice -eq "1") -or ($ReleaseChoice -eq "2") ) 
    {
      return $ReleaseChoice
    }
    elseif (($ReleaseChoice -eq "0"))
    {
      Exit
    }
    else
    {
      Write-Error "Wrong input '$($ReleaseChoice)'."
      $ReleaseChoice = $NULL
    }
  }
}

function Read-Version-Choice ($VersionChoiceArray)
{
  while (!$NextVersionIndexInput)
  {
    $NumberOfVersions = $VersionChoiceArray.Count

    for ($i = 1; $i -le $NumberOfVersions; $i++)
    {
      $OutputString = "[$($i)] $($VersionChoiceArray[$i-1])"
      Write-Host $OutputString
    }

    Write-Host "[0] Exit"

    $NextVersionIndexInput = Read-Host "Please enter your choice"
    
    #Default Value if nothing gets entered
    if ([string]::IsNullOrEmpty($NextVersionIndexInput))
    {
      return $VersionChoiceArray[0]
    }
    
    #User wants to exit
    if ($NextVersionIndexInput -eq "0")
    {
      Exit
    }

    $NextVersionIndexInputParsed = $NextVersionIndexInput -as [int]

    if ($NextVersionIndexInputParsed -eq $NULL)
    {
      Write-Error "You have to enter a number between 1-$($NumberOfVersions + 1)"
      $NextVersionIndexInput = $NULL
    }
    elseif (($NextVersionIndexInput -lt 1) -or ($NextVersionIndexInput -gt $NumberOfVersions) )
    {
      Write-Error "You have to enter a number between 1-$($NumberOfVersions + 1)"
      $NextVersionIndexInput = $NULL
    }
    else
    {
      return $VersionChoiceArray[$NextVersionIndexInput - 1]
    }
  }
}

function Read-Continue ($DefaultSwitched)
{
  if ($DefaultSwitched)
  {
    $Default = "Y"
    $NotDefault = "N"
    $DefaultReturnValue = $TRUE
  }
  else
  {
    #N is the normal Default because not to continue is most of the time the more harmless option
    $Default = "N"
    $NotDefault = "Y"
    $DefaultReturnValue = $FALSE
  }

  $ContinueChoice = Read-Host "Your Working Directory is not clean. Continue? ($($Default)/$($NotDefault))"
    
  if([string]::IsNullOrEmpty($ContinueChoice))
  {
    return $DefaultReturnValue
  }
  elseif ($ContinueChoice.ToUpper() -eq "Y")
  {
    return $TRUE
  }
  else
  {
    return $FALSE
  }

  return $FALSE
}

function Read-Current-Version ()
{
  $CurrentVersion = Read-Host "No version found. Please enter version you want to release (as example: '1.0.0-alpha.1')"
      
  if (-not (Is-Semver $CurrentVersion))
  {
    Write-Error "Version '$($CurrentVersion)' is no valid SemVer."
    return Read-Current-Version
  }

  return $CurrentVersion
}


function Read-Ancestor-Choice ($ExpectedAncestors, $ReturnAncestor) 
{
  Write-Host "We expected to find one of following Ancestors: '$ExpectedAncestors', but found multiple possible Ancestors."
  $ChosenAncestor = Read-Version-Choice $ReturnAncestor
  return $ChosenAncestor
}