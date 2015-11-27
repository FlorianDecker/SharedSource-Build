function Parse-Semver ($Semver)
{
    $regex= "^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(-(?<pre>alpha|beta|rc)\.(?<preversion>\d+))?$"
     
    if(-not [regex]::IsMatch($Semver, $Regex, 'MultiLine'))
    {
      throw "Your version '$($Semver)' does not have a valid format (e.g. 1.2.3-alpha.1)."
    }

    return [regex]::Match($Semver, $Regex)
}

function Get-Possible-Next-Versions-Develop ($Version)
{
    $Match = Parse-Semver $Version

    $Major = $Match.Groups["major"].ToString()
    $Minor = $Match.Groups["minor"].ToString()
    $Patch = $Match.Groups["patch"].ToString()      

    $NextMajor = [string](1 + $Major)
    $NextMinor = [string](1 + $Minor)
    
    $NextPossibleMajor = "$($NextMajor).0.0"
    $NextPossibleMinor = "$($Major).$($NextMinor).0"

    #Compute 1.2.3-alpha.4 
    if ($Match.Groups["pre"].Success)
    {
      $Pre = $Match.Groups["pre"].ToString()
      $PreVersion = $Match.Groups["preversion"].ToString()  

      $NextPreVersion = [string](1 + $PreVersion)
      $NextPossiblePreVersion = "$($Major).$($Minor).$($Patch)-$($Pre).$($NextPreVersion)" 

      if ($Pre -eq "alpha")
      {
        $NextPossiblePre = "$($Major).$($Minor).$($Patch)-beta.1"

        return $NextPossiblePreVersion, $NextPossiblePre, $NextPossibleMinor, $NextPossibleMajor       
      }
      elseif ($Pre -eq "beta")
      {
        return $NextPossiblePreVersion, $NextPossibleMinor, $NextPossibleMajor 
      }
      elseif ($Pre -eq "rc")
      {
        return $NextPossiblePreVersion, $NextPossibleMinor, $NextPossibleMajor
      }
    }
    else
    {
      return "$($NextPossibleMinor)-alpha.1", "$($NextPossibleMinor)-beta.1", $NextPossibleMinor, $NextPossibleMajor
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

      $NextPreVersion = [string](1 + $PreVersion)
      $NextPossiblePreVersion = "$($Major).$($Minor).$($Patch)-$($Pre).$($NextPreVersion)" 

      if ($Pre -eq "alpha")
      {
        $NextPossiblePre = "$($Major).$($Minor).$($Patch)-beta.1"

        return $NextPossiblePreVersion, $NextPossiblePre, $NextPossiblePatch
      }
      elseif ($Pre -eq "beta")
      {
        return $NextPossiblePreVersion, $NextPossiblePatch
      }
      elseif ($Pre -eq "rc")
      {
        return $NextPossiblePreVersion, $NextPossiblePatch
      }
    }
    else
    {
      return $NextPossiblePatch, "$($NextPossiblePatch)-alpha.1", "$($NextPossiblePatch)-alpha.1"
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
      else
      {
        return "$($Major).$($Minor).$($Patch)-rc.1"
      }
    }      
    else
    {
      return "$($Major).$($Minor).$($Patch)-rc.1"
    }
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