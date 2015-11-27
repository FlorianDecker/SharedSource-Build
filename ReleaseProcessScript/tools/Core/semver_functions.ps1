function Parse-Semver ($Semver)
{
    $regex= "^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(-(?<pre>alpha|beta|rc)\.(?<preversion>\d+))?$"
     
    if(-not [regex]::IsMatch($Semver, $Regex, 'MultiLine'))
    {
      throw "Your version '$($Semver)' does not have a valid format (e.g. 1.2.3-alpha.1)."
    }

    return [regex]::Match($Semver, $Regex)
}

function Get-Possible-Next-Versions-Develop ($Version, $WithoutPrerelease)
{
    $Match = Parse-Semver $Version

    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()
    $Patch = $Match.Groups["patch"].ToString()      

    $NextMajor = [string](1 + $Major)
    $NextMinor = [string](1 + $Minor)
    $NextPatch = [string](1 + $Patch)
    
    $NextPossibleMajor = "$($NextMajor).0.0"
    $NextPossibleMinor = "$($Major).$($NextMinor).0"
    $NextPossiblePatch = "$($Major).$($Minor).$($NextPatch)"

    #Compute 1.2.3-alpha.4 
    if ($Match.Groups["pre"].Success)
    {
      $Pre = $Match.Groups["pre"].ToString()
      $PreVersion = $Match.Groups["preversion"].ToString()  
      $NextPossibleFullVersion = "$($Major).$($Minor).$($Patch)"

      $NextPreVersion = [string](1 + $PreVersion)
      $NextPossiblePreVersion = "$($Major).$($Minor).$($Patch)-$($Pre).$($NextPreVersion)" 

      if ($Pre -eq "alpha")
      {
        $NextPossiblePre = "$($Major).$($Minor).$($Patch)-beta.1"

        return $NextPossiblePreVersion, $NextPossiblePre, $NextPossibleFullVersion, "$($NextPossibleMajor)-alpha.1", "$($NextPossibleMajor)-beta.1", $NextPossibleMajor
      }
      elseif ($Pre -eq "beta")
      {
        return $NextPossiblePreVersion, $NextPossibleFullVersion, "$($NextPossibleMajor)-alpha.1", "$($NextPossibleMajor)-beta.1", $NextPossibleMajor
      }
      elseif ($Pre -eq "rc")
      {
        #We dont return a NextPossiblePreVersion because you cant have a releasecandidate directly on develop. So the last version should not be a rc anyway.
        return $NextPossibleFullVersion, "$($NextPossibleMajor)-alpha.1", "$($NextPossibleMajor)-beta.1", $NextPossibleMajor
      }
    }
    else
    {
      if ($WithoutPrerelease)
      {
        return $NextPossibleMinor, $NextPossibleMajor
      }
      else
      {
        return "$($NextPossibleMinor)-alpha.1", "$($NextPossibleMinor)-beta.1", $NextPossibleMinor, $NextPossibleMajor, "$($NextPossibleMajor)-alpha.1", "$($NextPossibleMajor)-beta.1"
      }
    } 
}

function Get-Possible-Next-Versions-Support ($Version)
{
    $Match = Parse-Semver $Version

    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()
    $Patch = $Match.Groups["patch"].ToString()      
 
    $NextPatch = [string](1 + $Patch)
    $NextPossiblePatch = "$($Major).$($Minor).$($NextPatch)"

    #Compute 1.2.3-alpha.4 
    if ($Match.Groups["pre"].Success)
    {
      $Pre = $Match.Groups["pre"].ToString()
      $PreVersion = $Match.Groups["preversion"].ToString()
      $NextPossibleFullVersion = "$($Major).$($Minor).$($Patch)"  

      $NextPreVersion = [string](1 + $PreVersion)
      $NextPossiblePreVersion = "$($Major).$($Minor).$($Patch)-$($Pre).$($NextPreVersion)" 

      if ($Pre -eq "alpha")
      {
        $NextPossiblePre = "$($Major).$($Minor).$($Patch)-beta.1"

        return $NextPossiblePreVersion, $NextPossiblePre, $NextPossibleFullVersion
      }
      elseif ($Pre -eq "beta")
      {
        return $NextPossiblePreVersion, $NextPossibleFullVersion
      }
      elseif ($Pre -eq "rc")
      {
        return $NextPossiblePreVersion, $NextPossibleFullVersion
      }
    }
    else
    {
      return $NextPossiblePatch, "$($NextPossiblePatch)-alpha.1", "$($NextPossiblePatch)-beta.1"
    } 
}

function Get-Next-Rc ($CurrentVersion)
{
    $Match = Parse-Semver $CurrentVersion

    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()
    $Patch = $Match.Groups["patch"].ToString()


    if ($Match.Groups["pre"].Success)
    {

      $Pre = $Match.Groups["pre"].ToString()
      $PreVersion = $Match.Groups["preversion"].ToString()
      
      $NextPreVersion = [string](1 + $PreVersion)

      if ($Pre -eq "rc")
      {
        return "$($Major).$($Minor).$($Patch)-rc.$($NextPreVersion)"
      }
    }      
    
    return "$($Major).$($Minor).$($Patch)-rc.1"
}

function Get-Next-AlphaBeta ($CurrentVersion)
{
    $Match = Parse-Semver $CurrentVersion

    if ($Match.Groups["pre"].Success)
    {
      $Major = $Match.Groups["major"].ToString()
      $Minor = $Match.Groups["minor"].ToString()
      $Patch = $Match.Groups["patch"].ToString()

      $Pre = $Match.Groups["pre"].ToString()
      $PreVersion = $Match.Groups["preversion"].ToString()
      
      $NextPreVersion = [string](1 + $PreVersion)

      if ( ($Pre -eq "alpha") -or ($Pre -eq "beta") )
      {
        return "$($Major).$($Minor).$($Patch)-rc.$($NextPreVersion)"
      }
      else
      {
        return "$($Major).$($Minor).$($Patch)-alpha.1"
      }
    }
}

function Get-Next-Patch ($Version)
{
    $Match = Parse-Semver $Version
    
    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()
    $Patch = $Match.Groups["patch"].ToString()
    
    $NextPatch = [string](1 + $Patch)

    return "$($Major).$($Minor).$($NextPatch)"
}

function Get-PreReleaseStage ($Version)
{
    $Match = Parse-Semver $Version
    
    if ($Match.Groups["pre"].Success)
    {
      $Pre = $Match.Groups["pre"].ToString()
           
      return $Pre
    }
    else
    {
      return $NULL
    }
    
    return $NULL
}

function Get-Major-Minor-From-Version ($Version)
{
    $Match = Parse-Semver $Version
    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()     
      
    return "$($Major).$($Minor)"
}

function Get-Version-Without-Pre ($Version)
{
    $Match = Parse-Semver $Version
    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()     
    $Patch = $Match.Groups["patch"].ToString()

    return "$($Major).$($Minor).$($Patch)"
}

function Get-Most-Recent-Version ($Version1, $Version2)
{
    if ([string]::IsNullOrEmpty($Version1))
    {
        return $Version2
    }

    if ([string]::IsNullOrEmpty($Version2))
    {
        return $Version1
    }
    
    if ( $Version1 -eq $Version2)
    {
      return $Version1
    }

    $ParsedVersion1 = Parse-Semver $Version1
    $ParsedVersion2 = Parse-Semver $Version2

    $Major1 = $ParsedVersion1.Groups["major"].ToString()
    $Major2 = $ParsedVersion2.Groups["major"].ToString()

    $Minor1 = $ParsedVersion1.Groups["minor"].ToString()
    $Minor2 = $ParsedVersion2.Groups["minor"].ToString()
    
    $Patch1 = $ParsedVersion1.Groups["patch"].ToString()
    $Patch2 = $ParsedVersion2.Groups["patch"].ToString()

    if ($Major1 -gt $Major2) 
    {
        return $Version1
    }
    if ($Major1 -lt $Major2)
    {
        return $Version2
    }


    if ($Minor1 -gt $Minor2)
    {
        return $Version1
    }
    if ($Minor1 -lt $Minor2)
    {
        return $Version2
    }


    if ($Patch1 -lt $Patch2)
    {
        return $Version1
    }
    if ($Patch1 -lt $Patch2)
    {
        return $Version2
    }

    
    if ($ParsedVersion1.Groups["pre"].Success -and (-not $ParsedVersion2.Groups["pre"].Success) )
    {
        return $Version2
    }
    if ((-not $ParsedVersion1.Groups["pre"].Success) -and $ParsedVersion2.Groups["pre"].Success)
    {
        return $Version1
    }



    $Pre1 = $Version1.Groups["pre"].ToString()
    $Pre2 = $Version2.Groups["pre"].ToString()

    $PreVersion1 = $Version1.Groups["preversion"].ToString()
    $PreVersion2 = $Version2.Groups["preversion"].ToString()

    if ($Pre1 -gt $Pre2)
    {
        return $Version1
    }
    if ($Pre1 -lt $Pre2)
    {
        return $Version2
    }


    if ($PreVersion1 -lt $PreVersion2)
    {
        return $Version1
    }

    if ($PreVersion1 -lt $PreVersion2)
    {
        return $Version2
    }


    return $NULL
}