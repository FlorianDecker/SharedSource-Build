Import-Module $PSScriptRoot"\..\main_functions.psm1" -Force -DisableNameChecking

. $PSScriptRoot"\Test_Functions.ps1"
. $PSScriptRoot"\..\config_functions.ps1"
. $PSScriptRoot"\..\jira_functions.ps1"
. $PSScriptRoot"\..\main_complex_functions.ps1"
. $PSScriptRoot"\..\main_helper_functions.ps1"
. $PSScriptRoot"\..\read_functions.ps1"


$TestDirName = "GitUnitTestDir"
$PseudoRemoteTestDir = "RemoteTestDir"

Describe "release_process_script_flow" {

    BeforeEach {
      Get-Config-File
      $ConfigFilePath = Get-Config-File-Path
      Mock -ModuleName main_functions Get-Config-File-Path { return $ConfigFilePath }
      Mock -ModuleName main_functions Invoke-MsBuild-And-Commit { return }
      Mock -ModuleName main_functions Push-To-Repos { return }

      Test-Create-Repository $TestDirName
      cd $PSScriptRoot"\"$TestDirName
      Test-Mock-All-Jira-Functions
    }

    AfterEach {
      cd $PSScriptRoot
      Remove-Item -Recurse -Force $TestDirName
      Remove-Item -Recurse -Force $PseudoRemoteTestDir 2>&1 | Out-Null
    }

    Context "Release-Version Initial Choice" {
        It "Release-Version_OnSupportBranch_MockChoiceAlpha" {
           Mock -ModuleName main_functions Get-Support-Current-Version { return "1.1.1-alpha.1" }
           Mock -ModuleName main_functions Release-Alpha-Beta { return }

           git checkout -b "support/v1.1" --quiet

           Release-Version 

           Assert-MockCalled -ModuleName main_functions Release-Alpha-Beta -Times 1
       }
       
       It "Release-Version_OnSupportBranch_MockChoicePatch" {
           Mock -ModuleName main_functions Get-Support-Current-Version { return "1.1.1" }
           Mock -ModuleName main_functions Release-Support { return }

           git checkout -b "support/v1.1" --quiet
           
           Release-Version

           Assert-MockCalled -ModuleName main_functions Release-Support -Times 1
       }

       It "Release-Version_OnReleaseBranch_MockChoiceReleaseRC" {
           Mock -ModuleName main_functions Read-Release-Branch-Mode-Choice { return 1 }
           Mock -ModuleName main_functions Release-RC { return }

           git checkout -b "release/v1.0.0" --quiet

           Release-Version

           Assert-MockCalled -ModuleName main_functions Release-RC -Times 1
       }
       
       It "Release-Version_OnReleaseBranch_MockChoiceReleaseOnMaster" {
           Mock -ModuleName main_functions Read-Release-Branch-Mode-Choice { return 2 }
           Mock -ModuleName main_functions Release-With-RC { return }

           git checkout -b "release/v1.0.0" --quiet

           Release-Version

           Assert-MockCalled -ModuleName main_functions Release-With-RC -Times 1
       }

       It "Release-Version_OnDevelopBranch_MockChoiceAlpha" {
           Mock -ModuleName main_functions Get-Develop-Current-Version { return "1.2.0-alpha.1" }
           Mock -ModuleName main_functions Release-Alpha-Beta { return }
           git checkout -b develop --quiet

           Release-Version

           Assert-MockCalled -ModuleName main_functions Release-With-RC -Times 1
       }

       It "Release-Version_OnDevelopBranch_MockChoiceMinor" {
           Mock -ModuleName main_functions Get-Develop-Current-Version { return "1.3.0" }
           Mock -ModuleName main_functions Release-On-Master { return }
           git checkout -b develop --quiet
           
           Release-Version

           Assert-MockCalled -ModuleName main_functions Release-On-Master -Times 1
       }
    }

    }
}