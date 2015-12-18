function Read-Choice-Of-Two ()
{
    try
    {
      [int]$ReleaseChoice = Read-Host "Please enter 1 or 2"
    }
    catch
    {
      [ArgumentException]
      throw "You have to enter 1 or 2."
    }

    #If nothing gets entered, $ReleaseChoice = 0
    if ($ReleaseChoice -eq 0)
    {
      return 1
    }

    if ( ($ReleaseChoice -eq 1) -or ($ReleaseChoice -eq 2) )
    {
      return $ReleaseChoice
    }
    else
    {
      throw "You have to enter either 1 or 2."  
    }

    throw "You have to enter either 1 or 2."
}

function Read-Version-Choice ($VersionChoiceArray)
{
    $NumberOfVersions = $VersionChoiceArray.Count

    for ($i = 1; $i -le $NumberOfVersions; $i++)
    {
      $OutputString = "[" + $i + "] " + $VersionChoiceArray[$i-1] + ""
      Write-Host $OutputString
    }

    try
    {
      [int]$NextVersionIndex = Read-Host "Please enter your choice"
    }
    catch
    {
      throw "$($NextVersionIndex)You have to enter a number between 1-" + $NumberOfVersions
    }

    #If nothing gets entered, $NextVersionIndex = 0
    if ($NextVersionIndex -eq 0)
    {
      return $VersionChoiceArray[0]
    }

    if ( ($NextVersionIndex -lt 1) -or ($NextVersionIndex -gt $NumberOfVersions) )
    {
      throw "You have to enter a number between 1-" + $NumberOfVersions
    }

    return $VersionChoiceArray[$NextVersionIndex - 1]
}

function Read-Continue ()
{
    $ContinueChoice = Read-Host "Your Working Directory is not clean. Continue? (Y/N)"
    
    if ($ContinueChoice.ToUpper() -eq "Y")
    {
      return $TRUE
    }
    else
    {
      return $FALSE
    }

    return $FALSE
}

function Read-Current-Version ($VersionFromTag)
{
    if ([string]::IsNullOrEmpty($VersionFromTag))
    {
      $CurrentVersion = Read-Host "No version found. Please enter version you want to release"
    } 
    else
    {
      $LastVersion = $VersionFromTag.substring(1)
      $CurrentPossibleVersions = Get-Possible-Next-Versions $LastVersion

      Write-Host "Please choose release-version: "
     
      $CurrentVersion = Read-Version-Choice $CurrentPossibleVersions
    }

    return $CurrentVersion
}