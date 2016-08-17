. $PSScriptRoot"\..\Core\git_base_functions.ps1"
. $PSScriptRoot"\Test_Functions.ps1"

#There was an Issue that $PSScriptRoot was null in BeforeEach/AfterEach, so we have to cache it here
$ScriptRoot = $PSScriptRoot

$TestBaseDir = "C:\temp"
$TestDirName = "GitUnitTestDir"

Describe "get-ancestor_function" {
  BeforeEach {
    cd $ScriptRoot

    Test-Create-Repository "$($TestBaseDir)\\$($TestDirName)"
    cd "$($TestBaseDir)\\$($TestDirName)"

    if(-not $?)
    {
      #cd failed, we dont want the test to run
      throw "cd command failed, abort test"
    }
  }

  AfterEach {
    cd $TestBaseDir
    Remove-Item -Recurse -Force $TestDirName 2>&1 | Out-Null
    cd $ScriptRoot
  }

  Context "Get-Ancestor" {
    It "Get-Ancestor_developBehindReleaseBranch" {
      Test-Add-Commit
      git checkout -b develop --quiet
      Test-Add-Commit
      git checkout -b release/v1.0.1 --quiet

      Get-Ancestor "develop" | Should Be "develop"
    }
    
    It "Get-Ancestor_releaseBehindDevelopBranch" {
      Test-Add-Commit
      git checkout -b develop --quiet
      Test-Add-Commit
      git checkout -b release/v1.0.1 --quiet
      
      git checkout develop --quiet
      Test-Add-Commit
      git checkout release/v1.0.1 --quiet

      Get-Ancestor "develop" | Should Be "develop"
    }

    It "Get-Ancestor_releaseOnSameCommitAsDevelop" {
      Test-Add-Commit
      git checkout -b develop --quiet
      git checkout -b release/v1.0.1 --quiet
  
      Get-Ancestor "develop" | Should Be "develop"
    }
  }
}