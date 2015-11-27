
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