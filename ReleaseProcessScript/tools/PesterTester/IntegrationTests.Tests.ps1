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
$RemoteTestDir = "$($TestBaseDir)\ReleaseProcessScriptRemoteTestRepository" 
$TestDirName = "GitUnitTestDir"
$PseudoRemoteTestDir = "RemoteTestDir"

Describe "IntegrationTests" {
  
  BeforeEach {
    #Mock Things which we dont want to test automated in an integration test as they could break something online
    Test-Mock-All-Jira-Functions

    #Assure that the TestDir does not already exist
    Test-Path $TestDir | Should Be False
    Test-Path $RemoteTestDir | Should Be False

    New-Item -ItemType directory -Path $RemoteTestDir
    cd $RemoteTestDir
    git init --bare --quiet
    cd $ScriptRoot
  }

  AfterEach {
    cd $ScriptRoot
    Remove-Item $TestDir -Recurse -Force  
    Remove-Item $RemoteTestDir -Recurse -Force  
  }

  Context "ReleaseFromMaster" {
    It "ReleasePatchOnMaster" {
        
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\BaseDirectory" -Recurse
      cd $TestDir    
      
      git remote add -f origin "$($RemoteTestDir)"
      git push --all origin
        
      Mock Read-Version-Choice { return "1.0.2" }
      git checkout master --quiet
      
      { Release-Version } | Should Not Throw
        
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleasePatchOnMaster"
      git remote update

      git checkout master --quiet

      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff release/v1.0.1 remotes/MasterRepo/release/v1.0.1 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin
        
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleasePatchOnMaster"
      
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.0.1"

      #Check if Remote is in correct state
      Test-Compare-Branches $RemoteTestDir "release/v1.0.1"
      Test-Compare-Branches $RemoteTestDir "master"
    }
  }
    
  Context "ReleaseFromDevelop" {
    It "ReleaseVersionOnMaster" {

      Copy-Item -Destination $TestDir -Path ".\TestDirectories\BaseDirectory" -Recurse
      cd $TestDir

      git checkout master --quiet

      #Add support branch to see if possible other branches do not influence the test run
      git checkout -b support/v1.0
      git commit --allow-empty -m "Now we have support lingering around somewhere in the log"
    
      git checkout master --quiet
        
      git checkout -b develop --quiet

      git remote add -f origin $RemoteTestDir
      git push --all origin
      
      Mock Get-Develop-Current-Version { return "1.1.0" }
      Mock Read-Version-Choice { return "1.2.0" }
      
      { Release-Version } | Should Not Throw
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseVersionOnMaster"
      git remote update

      git checkout master --quiet

      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff release/v1.1.0 remotes/MasterRepo/release/v1.1.0 | Should BeNullOrEmpty 
      git diff support/v1.0 remotes/MasterRepo/support/v1.0 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin
            
      #Compare Logs
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseVersionOnMaster"
      
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.0"
      Test-Compare-Branches $BaseCompareDirectory "support/v1.0"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "develop"
      Test-Compare-Branches $RemoteTestDir "release/v1.1.0"
      Test-Compare-Branches $RemoteTestDir "support/v1.0"
    }

    It "ReleasePrereleaseVersion" {
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\BaseDirectory" -Recurse
      cd $TestDir

      git checkout master --quiet
      git checkout -b develop --quiet
      
      git remote add -f origin $RemoteTestDir
      git push --all origin

      Mock Get-Develop-Current-Version { return "1.1.0-alpha.1" }
      Mock Read-Version-Choice { return "1.2.0" }
      
      { Release-Version } | Should Not Throw
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleasePrereleaseOnDevelop"
      git remote update

      git checkout master --quiet

      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff prerelease/v1.1.0-alpha.1 remotes/MasterRepo/prerelease/v1.1.0-alpha.1 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin
      
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleasePrereleaseOnDevelop"
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "prerelease/v1.1.0-alpha.1"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "develop"
      Test-Compare-Branches $RemoteTestDir "prerelease/v1.1.0-alpha.1"
    }
  }
  
  Context "ReleaseFromSupport" {
    It "ReleaseVersionOnSupport" {
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\BaseDirectory" -Recurse
      cd $TestDir

      git checkout master --quiet
      git checkout -b support/v1.1

      git remote add -f origin $RemoteTestDir
      git push --all origin

      Mock Get-Support-Current-Version { return "1.1.1" }
      Mock Read-Version-Choice { return "1.2.0" }

      { Release-Version } | Should Not Throw
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseVersionOnSupport"
      git remote update
      
      git checkout master --quiet
      
      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff support/v1.1 remotes/MasterRepo/support/v1.1 | Should BeNullOrEmpty 
      git diff release/v1.1.1 remotes/MasterRepo/prerelease/v1.1.1 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin
      
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseVersionOnSupport"
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "support/v1.1"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.1"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "support/v1.1"
      Test-Compare-Branches $RemoteTestDir "release/v1.1.1"
    }
  }

  Context "ReleaseFromReleasebranch" {
    It "ReleaseRC" {
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\BaseDirectory" -Recurse
      cd $TestDir
      
      git checkout -b develop --quiet
      git checkout -b release/v1.1.0 --quiet
      
      git remote add -f origin $RemoteTestDir
      git push --all origin

      Mock Read-Choice-Of-Two { return 1 }
      Mock Read-Version-Choice { return "1.2.0" }

      { Release-Version } | Should Not Throw

      git checkout master --quiet
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseRC"
      git remote update
      
      
      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff prerelease/v1.1.0-rc.1 remotes/MasterRepo/prerelease/v1.1.0-rc.1 | Should BeNullOrEmpty 
      git diff release/v1.1.0 remotes/MasterRepo/release/v1.1.0 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin

      git checkout master --quiet
      
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseRC"
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "prerelease/v1.1.0-rc.1"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.0"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "develop"
      Test-Compare-Branches $RemoteTestDir "prerelease/v1.1.0-rc.1"
      Test-Compare-Branches $RemoteTestDir "release/v1.1.0"
    }

    It "ReleaseOnMaster" {
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\ReleaseRC" -Recurse
      cd $TestDir
      
      git checkout release/v1.1.0 --quiet
      
      git remote add -f origin $RemoteTestDir
      git push --all origin
            
      Mock Read-Choice-Of-Two { return 2 }
      Mock Read-Version-Choice { return "1.2.0" }

      { Release-Version } | Should Not Throw

      git checkout master --quiet
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMaster"
      git remote update
      
      
      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff prerelease/v1.1.0-rc.1 remotes/MasterRepo/prerelease/v1.1.0-rc.1 | Should BeNullOrEmpty 
      git diff release/v1.1.0 remotes/MasterRepo/release/v1.1.0 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin

      git checkout master --quiet
      
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMaster"
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "prerelease/v1.1.0-rc.1"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.0"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "develop"
      Test-Compare-Branches $RemoteTestDir "prerelease/v1.1.0-rc.1"
      Test-Compare-Branches $RemoteTestDir "release/v1.1.0"
    }

    It "ReleaseOnMasterWithDevelopHeaderNotOnReleaseBranchRoot" {
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\ReleaseRC" -Recurse
      cd $TestDir
      
      git checkout develop --quiet
      git commit --allow-empty -m "Develop is now ahead of the ReleaseBranch Root"
      git checkout release/v1.1.0 --quiet
     
      git remote add -f origin $RemoteTestDir
      git push --all origin
              
      Mock Read-Choice-Of-Two { return 2 }
      Mock Read-Version-Choice { return "1.2.0" }

      { Release-Version } | Should Not Throw

      git checkout master --quiet
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMasterReleaseRootBehindDevelop"
      git remote update
      
      
      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff prerelease/v1.1.0-rc.1 remotes/MasterRepo/prerelease/v1.1.0-rc.1 | Should BeNullOrEmpty 
      git diff release/v1.1.0 remotes/MasterRepo/release/v1.1.0 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin

      git checkout master --quiet
      
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMasterReleaseRootBehindDevelop"
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "prerelease/v1.1.0-rc.1"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.0"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "develop"
      Test-Compare-Branches $RemoteTestDir "prerelease/v1.1.0-rc.1"
      Test-Compare-Branches $RemoteTestDir "release/v1.1.0"
    }
  }

  Context "ContinueRelease" {
    It "PauseForCommitReleaseOnMaster" {
      Copy-Item -Destination $TestDir -Path ".\TestDirectories\BaseDirectory" -Recurse
      cd $TestDir

      git checkout master --quiet

      #Add support branch to see if possible other branches do not influence the test run
      git checkout -b support/v1.0
      git commit --allow-empty -m "Now we have support lingering around somewhere in the log"
            
      git checkout master --quiet
      git checkout -b develop --quiet

      Mock Get-Develop-Current-Version { return "1.1.0" }
      Mock Read-Version-Choice {return "1.2.0"}

      { Release-Version -PauseForCommit } | Should Not Throw

      git checkout master --quiet
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMasterPauseForCommit"
      git remote update
      
      
      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff support/v1.0 remotes/MasterRepo/support/v1.0 | Should BeNullOrEmpty 
      git diff release/v1.1.0 remotes/MasterRepo/release/v1.1.0 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo

      git checkout master --quiet
      #Compare commit Trees
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMasterPauseForCommit"
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "support/v1.0"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.0"
    }

    It "ContinueReleaseAfterPauseForCommitReleaseOnMaster" {
      robocopy "$($ScriptRoot)\TestDirectories\ReleaseReleaseOnMasterPauseForCommit" $TestDir /e
      cd $TestDir
      
      git remote add -f origin $RemoteTestDir
      git push --all origin
      
      git checkout release/v1.1.0 --quiet

      { Continue-Release } | Should Not Throw
      
      git checkout master --quiet
      git remote add -f MasterRepo "$($ScriptRoot)\TestDirectories\ReleaseVersionOnMaster"
      git remote update

      git checkout master --quiet

      #Compare File Structure
      git diff master remotes/MasterRepo/master | Should BeNullOrEmpty 
      git diff develop remotes/MasterRepo/develop | Should BeNullOrEmpty 
      git diff release/v1.1.0 remotes/MasterRepo/release/v1.1.0 | Should BeNullOrEmpty 
      git diff support/v1.0 remotes/MasterRepo/support/v1.0 | Should BeNullOrEmpty 
      
      #Delete remote as we dont need the file information of the remote anymore and the reference information is in the way of a clean git log comparison
      git remote rm MasterRepo
      git remote rm origin
            
      #Compare Logs
      $BaseCompareDirectory = "$($ScriptRoot)\TestDirectories\ReleaseVersionOnMaster"
      
      Test-Compare-Branches $BaseCompareDirectory "master"
      Test-Compare-Branches $BaseCompareDirectory "develop"
      Test-Compare-Branches $BaseCompareDirectory "release/v1.1.0"
      Test-Compare-Branches $BaseCompareDirectory "support/v1.0"

      Test-Compare-Branches $RemoteTestDir "master"
      Test-Compare-Branches $RemoteTestDir "develop"
      Test-Compare-Branches $RemoteTestDir "release/v1.1.0"
      Test-Compare-Branches $RemoteTestDir "support/v1.0"
    } 
  }
}