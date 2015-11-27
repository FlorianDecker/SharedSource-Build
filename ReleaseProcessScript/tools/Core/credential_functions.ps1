$Location = $PSScriptRoot

. $Location"\config_functions.ps1"
. $Location"\load_dll.ps1"

$jiraInvalidCredentialsExceptionString = "JIRA response: invalid credentials. Please try again."

function Save-Credential ($Username, $Password)
{
    Delete-Credentials

    $PasswordCredential = Create-Password-Credential $Username $Password

    [Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime] > $NULL
    $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault
    $PasswordVault.Add($PasswordCredential)
}

function Create-Password-Credential ($Username, $Password)
{
    $ConfigFile = Get-Config-File
    $JiraCredentialResourceString = "RemotionJira$($ConfigFile.settings.jira.jiraProjectKey)"

    [Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime] > $NULL
    $PasswordCredential = New-Object Windows.Security.Credentials.PasswordCredential

    $PasswordCredential.UserName = $Username    
    $PasswordCredential.Password = $Password
    $PasswordCredential.Resource = $JiraCredentialResourceString

    return $PasswordCredential 
}

function Get-Credential ()
{
    [Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime] > $NULL
    $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault

    $ConfigFile = Get-Config-File
    $JiraCredentialResourceString = "RemotionJira$($ConfigFile.settings.jira.jiraProjectKey)"

    try
    {
      $Credential = $PasswordVault.FindAllByResource($JiraCredentialResourceString)
      $Credential.RetrievePassword()

      try
      {
        Check-Jira-Authentication $Credential.Username $Credential.Password
      }
      catch
      {
        if ($_.Exception.Message -eq $jiraInvalidCredentialsExceptionString)
        {
          Write-Host "Invalid JIRA credentials saved"
          Ask-For-Credential
        }
        else
        {
          throw $_.Exception.Message         
        }
      }
    }
    catch [System.Management.Automation.MethodInvocationException]
    {
      return Ask-For-Credential
    }

    return $Credential
}

function Delete-Credentials ()
{
    $ConfigFile = Get-Config-File
    $JiraCredentialResourceString = "RemotionJira$($ConfigFile.settings.jira.jiraProjectKey)"

    [Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime] > $NULL
    $PasswordVault = New-Object Windows.Security.Credentials.PasswordVault
    try
    {
      $Credentials = $PasswordVault.FindAllByResource($JiraCredentialResourceString)

    }
    catch [System.Management.Automation.MethodInvocationException]    
    {
      #In case we havent saved anything into PasswordVault before
      return
    }

    foreach($Credential in $Credentials)
    {
      $PasswordVault.Remove($Credential)
    }
}

function Ask-For-Credential ()
{
    Write-Host "Please enter your Jira Authentication Details"
    $Username = Read-Host "Username"
    $PasswordSecure = Read-Host "Password" -AsSecureString

    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordSecure))

    Check-Jira-Authentication $Username $Password

    $savePassword = Read-Host "Do you want to save the password? (Y/N)"

    if ($savePassword.ToUpper() -eq "Y")
    {
      Save-Credential $Username $Password
      Write-Host "Saved password"
    }

    return Create-Password-Credential $Username $Password
}

function Check-Jira-Authentication ($Username, $Password)
{
    try 
    {
      Jira-Check-Credentials $Username $Password
    }
    catch [Remotion.BuildTools.MSBuildTasks.Jira.ServiceFacadeImplementations.JiraException] 
    {
      $StatusCode = $_.Exception.HttpStatusCode

      if ($StatusCode -eq [System.Net.HttpStatusCode]::Forbidden -or $StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized)
      {
        throw $jiraInvalidCredentialsExceptionString           
      }
      else
      {
        throw "Authentication failed. Returned statusCode '$($StatusCode)'. Exception details: $($_.Exception)"
      }
    }
}