. $PSScriptRoot"\..\Core\main_functions.ps1"
. $PSScriptRoot"\Test_Functions.ps1"
. $PSScriptRoot"\..\Core\config_functions.ps1"
. $PSScriptRoot"\..\Core\jira_functions.ps1"
. $PSScriptRoot"\..\Core\main_complex_functions.ps1"
. $PSScriptRoot"\..\Core\main_helper_functions.ps1"
. $PSScriptRoot"\..\Core\read_functions.ps1"


$TestDirName = "GitUnitTestDir"
$PseudoRemoteTestDir = "RemoteTestDir"

Describe "release_process_script_flow" {

    BeforeEach {
      Get-Config-File
      $ConfigFilePath = Get-Config-File-Path
      Mock Get-Config-File-Path { return $ConfigFilePath }
      Mock Invoke-MsBuild-And-Commit { return }
      Mock Push-To-Repos { return }

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
           Mock Get-Support-Current-Version { return "1.1.1-alpha.1" }
           Mock Release-Alpha-Beta { return }

           git checkout -b "support/v1.1" --quiet

           Release-Version 

           Assert-MockCalled Release-Alpha-Beta -Times 1
       }
       
       It "Release-Version_OnSupportBranch_MockChoicePatch" {
           Mock Get-Support-Current-Version { return "1.1.1" }
           Mock Release-Patch { return }

           git checkout -b "support/v1.1" --quiet
           
           Release-Version

           Assert-MockCalled Release-Patch -Times 1
       }

       It "Release-Version_OnReleaseBranch_MockChoiceReleaseRC" {
           Mock Read-Choice-Of-Two { return 1 }
           Mock Release-RC { return }

           git checkout -b "release/v1.0.0" --quiet

           Release-Version

           Assert-MockCalled Release-RC -Times 1
       }
       
       It "Release-Version_OnReleaseBranch_MockChoiceReleaseOnMaster" {
           Mock Read-Choice-Of-Two { return 2 }
           Mock Release-With-RC { return }

           git checkout -b "release/v1.0.0" --quiet

           Release-Version

           Assert-MockCalled Release-With-RC -Times 1
       }

       It "Release-Version_OnDevelopBranch_MockChoiceAlpha" {
           Mock Get-Develop-Current-Version { return "1.2.0-alpha.1" }
           Mock Release-Alpha-Beta { return }
           git checkout -b develop --quiet

           Release-Version

           Assert-MockCalled Release-With-RC -Times 1
       }

       It "Release-Version_OnDevelopBranch_MockChoiceMinor" {
           Mock Get-Develop-Current-Version { return "1.3.0" }
           Mock Release-On-Master { return }
           git checkout -b develop --quiet
           
           Release-Version

           Assert-MockCalled Release-On-Master -Times 1
       }
    }

    Context "Release-Version Functions called" {
        It "ReleaseVersion_OnSupport_ReleaseSupport_ReleaseAlpha" {
           Mock Get-Support-Current-Version { return "1.1.1-alpha.1" }
           Mock Read-Version-Choice { return "1.1.1-alpha.2" }
           git checkout -b "support/v1.1" --quiet
           Test-Add-Commit

           { Release-Version }| Should Not Throw
        }    

        It "ReleaseVersion_OnSupport_ReleaseSupport_ReleasePatch" {
           Mock Get-Support-Current-Version { return "1.1.1" }
           Mock Read-Version-Choice { return "1.1.2" }

           git checkout -b "support/v1.1" --quiet

           { Release-Version }| Should Not Throw
        }
        
        It "Release-Version_OnReleaseBranch_ReleaseRC" {
           Mock Read-Choice-Of-Two { return 1 }
           Mock Read-Version-Choice { return "1.0.0-rc.2" }
           
           git checkout -b "develop" --quiet
           Test-Add-Commit


           git checkout -b "release/v1.0.0" --quiet

           { Release-Version }| Should Not Throw       
        }    

        It "Release-Version_OnReleaseBranch_ReleaseOnMaster" {
           Mock Read-Choice-Of-Two { return 2 }
           Mock Read-Version-Choice { return "1.1.0" }

           git checkout -b "develop" --quiet
           Test-Add-Commit
           git checkout -b "release/v1.0.0" --quiet

           { Release-Version }| Should Not Throw       
        }
        
        It "Release-Version_OnDevelopBranch_ReleaseAlpha" {
           Mock Get-Develop-Current-Version { return "1.2.0-alpha.1" }
           Mock Read-Version-Choice { return "1.2.0-alpha.2" }
           git checkout -b develop --quiet

           { Release-Version }| Should Not Throw     
       }

       It "Release-Version_OnDevelopBranch_ReleaseMinor" {
           Mock Get-Develop-Current-Version { return "1.3.0" }
           Mock Read-Version-Choice { return "1.3.0-alpha.1" }
           git checkout -b develop --quiet

           { Release-Version }| Should Not Throw     
       }    
    }
}