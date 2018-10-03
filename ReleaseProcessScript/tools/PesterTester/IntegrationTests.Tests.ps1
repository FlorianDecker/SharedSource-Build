. $PSScriptRoot"\..\Core\main_functions.ps1"
. $PSScriptRoot"\Test_Functions.ps1"
. $PSScriptRoot"\..\Core\config_functions.ps1"
. $PSScriptRoot"\..\Core\jira_functions.ps1"
. $PSScriptRoot"\..\Core\main_helper_functions.ps1"
. $PSScriptRoot"\..\Core\read_functions.ps1"
. $PSScriptRoot"\..\Core\semver_functions.ps1"


#There was an Issue that $PSScriptRoot was null in BeforeEach/AfterEach, so we have to cache it here
$ScriptRoot = $PSScriptRoot

$TestBaseDir = "C:\temp"
$TestDir = "$($TestBaseDir)\ReleaseProcessScriptTestRepository"
$TestDirName = "GitUnitTestDir"

#TODO: Add a MSBuild Step which commits something to test the correct git branching
#TODO: Same with File ignore

Describe "IntegrationTestsTest" {
  
  BeforeEach {
    #Mock Things which we dont want to test automated in an integration test as they could break something online
    Test-Mock-All-Jira-Functions
    Test-Path $TestDir | Should Be False
    
    #Create Base Directory
    New-Item $TestDir -ItemType directory

    Copy-Item releaseProcessScript.config -Destination $TestDir

    cd $TestDir
    $MarkerName = ".BuildProject"
    $MarkerTemplate = 
"<?xml version=`"1.0`" encoding=`"utf-8`"?>
<!--Marks the path fo the releaseProcessScript config file-->
<configFile>
    <path>releaseProcessScript.config</path>
    <buildToolsVersion>$($BuildToolsVersion)</buildToolsVersion>
</configFile>"

    New-Item -Type file -Name $MarkerName -Value $MarkerTemplate

    git init --quiet
    git add .
    git commit -m "First commit"
    git tag -a "v1.0.0" -m "v1.0.0"
    git checkout master --quiet

    New-Item -Name "TestFile.txt" -ItemType "file" -Value "SomeValue"
    
    git add .
    git commit -m "Second commit"
  }

  AfterEach {
    cd $ScriptRoot
    Remove-Item $TestDir -Recurse -Force  
  }

  Context "ReleaseFromMaster" {
    It "ReleasePatchOnMaster" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleasePatchOnMaster"
      Mock Read-Version-Choice { return "1.0.2" }
      git checkout master --quiet
    
      { Release-Version } | Should Not Throw
    
      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent
    
      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"
      Write-Host $CurrentLog
      
      $CurrentLog | Should Be $ExpectedLog
    }
  }
    
  Context "ReleaseFromDevelop" {
    It "ReleaseVersionOnMaster" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleaseVersionOnMaster"
      git checkout master --quiet

      #Add support branch to see if possible other branches do not influence the test run
      git checkout -b support/v1.0
      git commit --allow-empty -m "Now we have support lingering around somewhere in the log"
    
      git checkout master --quiet
        
      git checkout -b develop --quiet
      Mock Get-Develop-Current-Version { return "1.1.0" }
      Mock Read-Version-Choice { return "1.2.0" }
      
      { Release-Version } | Should Not Throw

      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent

      #Checkout the top branch so we view the whole history
      git checkout support/v1.0 --quiet

      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"

      $CurrentLog | Should Be $ExpectedLog
    }

    It "ReleasePrereleaseVersion" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleasePrereleaseOnDevelop"
      git checkout master --quiet
      git checkout -b develop --quiet

      Mock Get-Develop-Current-Version { return "1.1.0-alpha.1" }
      Mock Read-Version-Choice { return "1.2.0" }
      
      { Release-Version } | Should Not Throw

      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent

      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"

      $CurrentLog | Should Be $ExpectedLog
    }
  }

  
  Context "ReleaseFromSupport" {
    It "ReleaseVersionOnSupport" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleaseVersionOnSupport"

      git checkout master --quiet
      git checkout -b support/v1.1

      Mock Get-Support-Current-Version { return "1.1.1" }
      Mock Read-Version-Choice { return "1.2.0" }

      { Release-Version } | Should Not Throw

      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent

      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"

      $CurrentLog | Should Be $ExpectedLog
    }
  }

  Context "ReleaseFromReleasebranch" {
    It "ReleaseRC" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleaseRC"
      
      git checkout -b develop --quiet
      git checkout -b release/v1.1.0 --quiet

      Mock Read-Choice-Of-Two { return 1 }
      Mock Read-Version-Choice { return "1.2.0" }

      { Release-Version } | Should Not Throw
      
      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent

      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"

      $CurrentLog | Should Be $ExpectedLog
    }

    It "ReleaseOnMaster" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMaster"
    
      git checkout -b develop --quiet
      git checkout -b prerelease/v1.1.0-rc.1 --quiet
      git checkout -b release/v1.1.0 --quiet
    
      Mock Read-Choice-Of-Two { return 2 }
      Mock Read-Version-Choice { return "1.2.0" }
    
      { Release-Version } | Should Not Throw
    
      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent
    
      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"
    
      $CurrentLog | Should Be $ExpectedLog
    }
    
    It "ReleaseOnMasterWithDevelopHeaderNotOnReleaseBranchRoot" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleaseOnMasterWithDevelopHeaderNotOnReleaseBranchRoot"
    
      git checkout -b develop --quiet
      git checkout -b prerelease/v1.1.0-rc.1 --quiet
      git checkout -b release/v1.1.0 --quiet
      git commit --allow-empty -m "Develop is now ahead of the ReleaseBranch Root"
      git checkout release/v1.1.0 --quiet
              
      Mock Read-Choice-Of-Two { return 2 }
      Mock Read-Version-Choice { return "1.2.0" }
    
      { Release-Version } | Should Not Throw
    
      #Compare file structure
      $CurrentMasterContent = git ls-tree master
      $ExpectedMasterContent = Get-Content -Path "$($CurrentPath)\masterFileList.txt"
      
      $CurrentMasterContent | Should Be $ExpectedMasterContent
      
      $CurrentDevelopContent = git ls-tree develop
      $ExpectedDevelopContent = Get-Content -Path "$($CurrentPath)\developFileList.txt"
      
      $CurrentDevelopContent | Should Be $ExpectedDevelopContent
      
      #Compare commit Trees
      [string]$CurrentHeadLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedHeadLog = Get-Content -Path "$($CurrentPath)\developGitLog.txt"
      
      $CurrentHeadLog | Should Be $ExpectedHeadLog
      
      [string]$CurrentMasterLog = git log master --graph --pretty=format:'%d %s'
      [string]$ExpectedMasterLog = Get-Content -Path "$($CurrentPath)\masterGitLog.txt"
      
      $CurrentMasterLog | Should Be $ExpectedMasterLog
    }
  }

  Context "ContinueRelease" {
    It "PauseForCommitReleaseOnMaster" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMasterPauseForCommit"
      
      git checkout master --quiet
 
      #Add support branch to see if possible other branches do not influence the test run
      git checkout -b support/v1.0
      git commit --allow-empty -m "Now we have support lingering around somewhere in the log"
            
      git checkout master --quiet
      git checkout -b develop --quiet
 
      Mock Get-Develop-Current-Version { return "1.1.0" }
      Mock Read-Version-Choice {return "1.2.0"}
 
      { Release-Version -PauseForCommit } | Should Not Throw
 
      git checkout support/v1.0 --quiet

      #Compare file structure
      $CurrentContent = git ls-tree Head
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent

      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"

      $CurrentLog | Should Be $ExpectedLog
    }

    It "ContinueReleaseAfterPauseForCommitReleaseOnMaster" {
      $CurrentPath = "$($ScriptRoot)\TestDirectories\ContinueReleaseAfterPauseForCommitReleaseOnMaster"
      
      #Setup PauseForCommit
      git checkout master --quiet
    
      #Add support branch to see if possible other branches do not influence the test run
      git checkout -b support/v1.0
      git commit --allow-empty -m "Now we have support lingering around somewhere in the log"
            
      git checkout master --quiet
      git checkout -b develop --quiet
    
      Mock Get-Develop-Current-Version { return "1.1.0" }
      Mock Read-Version-Choice {return "1.2.0"}
    
      { Release-Version -PauseForCommit } | Should Not Throw
    
      #Test ContinueRelease
      git checkout release/v1.1.0 --quiet
    
      { Continue-Release } | Should Not Throw
    
      #Compare file structure
      $CurrentContent = git ls-tree master
      $ExpectedContent = Get-Content -Path "$($CurrentPath)\fileList.txt"
      
      $CurrentContent | Should Be $ExpectedContent
    
      #Checkout the top branch so we view the whole history
      git checkout support/v1.0 --quiet
    
      #Compare commit Trees
      [string]$CurrentLog = git log Head --graph --pretty=format:'%d %s'
      [string]$ExpectedLog = Get-Content -Path "$($CurrentPath)\gitLog.txt"
    
      $CurrentLog | Should Be $ExpectedLog
    } 
  }
}