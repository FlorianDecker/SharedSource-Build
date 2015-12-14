$Location = $PSScriptRoot

. $Location"\credential_functions.ps1"
. $Location"\load_dll.ps1"

$JiraUrlPostFix = "rest/api/2/"

function Add-JiraUrlPostfix-To-Config-Url ($ConfigUrl)
{
    if ($ConfigUrl.EndsWith("/") )
    {
      $ReturnUrl = $ConfigUrl + $JiraUrlPostFix
    }
    else
    {
      $ReturnUrl = $ConfigUrl + "/" + $JiraUrlPostFix    
    }

    return $ReturnUrl
}

function Add-Authentication ($JiraObject)
{
    if (-not (Config-Use-NTLM) )
    {
      $Credential = Get-Credential
      $JiraObject.JiraUsername = $Credential.Username
      $JiraObject.JiraPassword = $Credential.Password
    }
}

function Check-For-Empty-Config ($ConfigFile)
{
  if ([string]::IsNullOrWhiteSpace($ConfigFile.settings.jira.jiraUrl))
  {
    throw "Please enter the Jira Url into the config file."
  }

  if ([string]::IsNullOrWhiteSpace($ConfigFile.settings.jira.jiraProjectKey))
  {
    throw "Please enter the Jira Project Key into the config file."
  }
}


function Jira-Create-Version ($Version)
{
    Confirm-Class-Loaded
    $JiraCreateVersion = New-Object Remotion.BuildTools.MSBuildTasks.Jira.JiraCreateNewVersionWithVersionNumber
    $ConfigFile = Get-Config-File

    Check-For-Empty-Config $ConfigFile

    $JiraCreateVersion.JiraUrl = Add-JiraUrlPostfix-To-Config-Url $ConfigFile.settings.jira.jiraUrl
    $JiraCreateVersion.JiraProjectKey = $ConfigFile.settings.jira.jiraProjectKey
    $JiraCreateVersion.VersionNumber = $Version

    Add-Authentication $JiraCreateVersion

    try 
    {
      $JiraCreateVersion.Execute() > $NULL
    } 
    catch 
    {
      [System.InvalidOperationException]
      throw $_.Exception.Message
    }

    return $JiraCreateVersion.CreatedVersionID
}

function Jira-Get-Current-Version ()
{
    Confirm-Class-Loaded
    $JiraGetVersion = New-Object Remotion.BuildTools.MSBuildTasks.Jira.JiraGetEarliestUnreleasedVersion 

    $ConfigFile = Get-Config-File
    Check-For-Empty-Config $ConfigFile
    
    $JiraGetVersion.JiraUrl = Add-JiraUrlPostfix-To-Config-Url($ConfigFile.settings.jira.jiraUrl)
    $JiraGetVersion.JiraProject = $ConfigFile.settings.jira.jiraProjectKey
    $JiraGetVersion.VersionPattern = "(?s).*"

    Add-Authentication $JiraGetVersion

    $JiraGetVersion.Execute()

    $Version = New-Object -TypeName PSObject
    $Version |Add-Member -MemberType NoteProperty -Name VersionName -Value $JiraGetVersion.VersionName
    $Version |Add-Member -MemberType NoteProperty -Name VersionID -Value $JiraGetVersion.VersionID

    return $Version
}

function Jira-Release-Version ($CurrentVersionID, $NextVersionID, $SquashUnreleased)
{
    Confirm-Class-Loaded
    if ($SquashUnreleased)
    {
      $JiraReleaseVersion = New-Object Remotion.BuildTools.MSBuildTasks.Jira.JiraReleaseVersionAndSquashUnreleased
    }
    else
    {
      $JiraReleaseVersion = New-Object Remotion.BuildTools.MSBuildTasks.Jira.JiraReleaseVersion
    }
    
    $ConfigFile = Get-Config-File
    Check-For-Empty-Config $ConfigFile

    $JiraReleaseVersion.JiraUrl = Add-JiraUrlPostfix-To-Config-Url $ConfigFile.settings.jira.jiraUrl
    $JiraReleaseVersion.VersionID = $CurrentVersionID
    $JiraReleaseVersion.NextVersionID = $NextVersionID
    $JiraReleaseVersion.ProjectKey = $ConfigFile.settings.jira.jiraProjectKey

    Add-Authentication $JiraReleaseVersion

    $JiraReleaseVersion.Execute()
}

function Jira-Release-Version-And-Squash-Unreleased ($CurrentVersionID, $NextVersionID)
{
    Confirm-Class-Loaded
    $JiraReleaseVersionAndSquashUnreleased = New-Object Remotion.BuildTools.MSBuildTasks.Jira.JiraReleaseVersion
    $ConfigFile = Get-Config-File
    Check-For-Empty-Config $ConfigFile

    $JiraReleaseVersionAndSquashUnreleased.JiraUrl = Add-JiraUrlPostfix-To-Config-Url $ConfigFile.settings.jira.jiraUrl
    $JiraReleaseVersionAndSquashUnreleased.VersionID = $CurrentVersionID
    $JiraReleaseVersionAndSquashUnreleased.NextVersionID = $NextVersionID

    Add-Authentication $JiraReleaseVersionAndSquashUnreleased

    $JiraReleaseVersionAndSquashUnreleased.Execute()
}

function Jira-Check-Credentials ($Username, $Password)
{
    Confirm-Class-Loaded
    $JiraCheckAuthentication = New-Object Remotion.BuildTools.MSBuildTasks.Jira.JiraCheckAuthentication

    $ConfigFile = Get-Config-File
    Check-For-Empty-Config $ConfigFile

    $JiraCheckAuthentication.JiraUrl = Add-JiraUrlPostfix-To-Config-Url $ConfigFile.settings.jira.jiraUrl
    $JiraCheckAuthentication.JiraUsername = $Username
    $JiraCheckAuthentication.JiraPassword = $Password
    $JiraCheckAuthentication.JiraProject = $ConfigFile.settings.jira.jiraProjectKey
    
    $JiraCheckAuthentication.Execute()
}

function Confirm-Class-Loaded ()
{
    try
    {
      #We just use a random Classname to check if it is loaded
      if (-not ([Remotion.BuildTools.MSBuildTasks.Jira]'JiraCheckAuthentication').Type)
      {
        Load-Dependency-Dll
      }
    }
    catch
    {
      Load-Dependency-Dll
    }
}