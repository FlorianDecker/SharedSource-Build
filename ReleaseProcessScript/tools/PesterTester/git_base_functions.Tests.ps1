. $PSScriptRoot"\..\git_base_functions.ps1"
. $PSScriptRoot"\Test_Functions.ps1"

$TestDirName = "GitUnitTestDir"
$PseudoRemoteTestDir = "RemoteTestDir"

Describe "git_base_functions" {
    
    BeforeEach {
      Get-Config-File

      Test-Create-Repository $TestDirName
      cd "$($PSScriptRoot)\\$($TestDirName)"
    }

    AfterEach {
      cd $PSScriptRoot
      Remove-Item -Recurse -Force $TestDirName
      Remove-Item -Recurse -Force $PseudoRemoteTestDir 2>&1 | Out-Null
    }

    Context "Get-Branch-Exists" {
        It "Get-Branch-Exists_BranchExists_ReturnTrue" {
            git checkout -b "newBranch" --quiet
        
            Get-Branch-Exists "newBranch" | Should Be $TRUE
        }
       
        It "Get-Branch-Exists_BranchDoesNotExists_ReturnFalse" {
            Get-Branch-Exists "notExistingBranch" | Should Be $FALSE
        }
    }

    Context "Get-Branch-Exists-Remote" {
        It "Get-Branch-Exists-Remote_BranchExists_ReturnTrue" {
            git checkout -b "newBranch" --quiet
            Test-Add-Commit
            Test-Create-And-Add-Remote $TestDirName $PseudoRemoteTestDir
            cd "$($PSScriptRoot)\$($PseudoRemoteTestDir)"

            Get-Branch-Exists-Remote "$($PSScriptRoot)\$($TestDirName)" "newBranch" | Should Be $TRUE
        }

        It "Get-Branch-Exists-Remote_BranchDoesNotExists_ReturnFalse" {
            Test-Create-And-Add-Remote $TestDirName $PseudoRemoteTestDir
            cd "$($PSScriptRoot)\$($PseudoRemoteTestDir)"
            git checkout -b "notExistingOnRemote" --quiet


            Get-Branch-Exists-Remote "$($PSScriptRoot)\\$($TestDirName)" "notExistingOnRemote" | Should Be $FALSE
        }
    }

    Context "Get-Tag-Exists" {
        It "Get-Tag-Exists_TagExists_ReturnTrue" {
            git tag -a "newTag" -m "newTag" 2>&1 > $NULL

            Get-Tag-Exists "newTag" | Should Be $TRUE
        }
        
        It "Get-Tag-Exists_TagDoesNotExist_ReturnFalse" {
            Get-Tag-Exists "notExistingTag" | Should Be $FAlSE
        }
    }

    Context "Is-On-Branch" {
        It "Is-On-Branch_OnRightBranch_ReturnTrue" {
            Is-On-Branch "master" | Should Be $TRUE
        }

        It "Is-On-Branch_NotOnRightBranch_ReturnFalse" {
            Is-On-Branch "randomBranch" | Should Be $FALSE
        }

        It "Is-On-Branch-OnSubBranch_ReturnTrue" {
            git checkout -b "support/test" 2>&1 | Out-Null

            Is-On-Branch "support/" | Should Be $TRUE
        }

        It "Is-On-Branch_OnSubBranch_CalledWithoutSlash_ReturnFalse" {
            git checkout -b "support/test" 2>&1 | Out-Null

            Is-On-Branch "support" | Should Be $FALSE
        }
    }

    Context "Check-Branch-Up-To-Date" {
        It "Check-Branch-Up-To-Date_BrancheBehind_ShouldThrowException" {
            git checkout master --quiet
            Test-Add-Commit
            Test-Create-And-Add-Remote $TestDirName $PseudoRemoteTestDir

            git checkout master --quiet
            Test-Add-Commit

            cd "$($PSScriptRoot)\$($PseudoRemoteTestDir)"
            git checkout master --quiet
            
            $RemoteUrl = "$($PSScriptRoot)\$($TestDirName)"
            git remote add testRemote $RemoteUrl            
            
            $ConfigFile = Get-Config-File
          
            $OldRemoteUrlNodes = $ConfigFile.SelectNodes("//remoteUrl")
            foreach ($Node in $OldRemoteUrlNodes)
            {
              $ConfigFile.settings.remoteRepositories.RemoveChild($Node)
            }

            $RemoteUrlNode = $ConfigFile.CreateElement("remoteUrl")
            $ConfigFile.SelectSingleNode("//remoteRepositories").AppendChild($RemoteUrlNode)
            $ConfigFile.settings.remoteRepositories.remoteUrl = $RemoteUrl

            { Check-Branch-Up-To-Date "master" } | Should Throw "Need to pull, local 'master' branch is behind on repository '$($RemoteUrl)'."
        }

        It "Check-Branch-Up-To-Date_BranchesDiverged_ShouldThrowException" {
            git checkout master --quiet
            Test-Add-Commit
            Test-Create-And-Add-Remote $TestDirName $PseudoRemoteTestDir

            git checkout master --quiet
            Test-Add-Commit "--amend"


            cd "$($PSScriptRoot)\$($PseudoRemoteTestDir)"
            git checkout master --quiet
            
            $RemoteUrl = "$($PSScriptRoot)\$($TestDirName)"
            git remote add testRemote $RemoteUrl  
            $ConfigFile = Get-Config-File
          
            $OldRemoteUrlNodes = $ConfigFile.SelectNodes("//remoteUrl")
            foreach ($Node in $OldRemoteUrlNodes)
            {
              $ConfigFile.settings.remoteRepositories.RemoveChild($Node)
            }

            $RemoteUrlNode = $ConfigFile.CreateElement("remoteUrl")
            $ConfigFile.SelectSingleNode("//remoteRepositories").AppendChild($RemoteUrlNode)
            $ConfigFile.settings.remoteRepositories.remoteUrl = $RemoteUrl


            { Check-Branch-Up-To-Date "master" } | Should Throw "'master' diverged, need to rebase at repository '$($RemoteUrl)'."
        }

        It "Check-Branch-Up-To-Date_RemoteBranchBehind_ShouldNotThrow" {
            git checkout master --quiet
            Test-Add-Commit
            Test-Create-And-Add-Remote $TestDirName $PseudoRemoteTestDir

            cd "$($PSScriptRoot)\$($PseudoRemoteTestDir)"
            git checkout master --quiet
            Test-Add-Commit

            $RemoteUrl = "$($PSScriptRoot)\$($TestDirName)"
            git remote add testRemote $RemoteUrl
            $ConfigFile = Get-Config-File
          
            $OldRemoteUrlNodes = $ConfigFile.SelectNodes("//remoteUrl")
            foreach ($Node in $OldRemoteUrlNodes)
            {
              $ConfigFile.settings.remoteRepositories.RemoveChild($Node)
            }

            $RemoteUrlNode = $ConfigFile.CreateElement("remoteUrl")
            $ConfigFile.SelectSingleNode("//remoteRepositories").AppendChild($RemoteUrlNode)
            $ConfigFile.settings.remoteRepositories.remoteUrl = $RemoteUrl

            { Check-Branch-Up-To-Date "master" } | Should Not Throw 
        }

        It "Check-Branch-Up-To-Date_BranchesEqual_ShouldNotThrow" {
            git checkout master --quiet
            Test-Add-Commit
            Test-Create-And-Add-Remote $TestDirName $PseudoRemoteTestDir

            cd "$($PSScriptRoot)\$($PseudoRemoteTestDir)"
            git checkout master --quiet

            $RemoteUrl = "$($PSScriptRoot)\$($TestDirName)"
            git remote add testRemote $RemoteUrl
            $ConfigFile = Get-Config-File
          
            $OldRemoteUrlNodes = $ConfigFile.SelectNodes("//remoteUrl")
            foreach ($Node in $OldRemoteUrlNodes)
            {
              $ConfigFile.settings.remoteRepositories.RemoveChild($Node)
            }

            $RemoteUrlNode = $ConfigFile.CreateElement("remoteUrl")
            $ConfigFile.SelectSingleNode("//remoteRepositories").AppendChild($RemoteUrlNode)
            $ConfigFile.settings.remoteRepositories.remoteUrl = $RemoteUrl

            { Check-Branch-Up-To-Date "master" } | Should Not Throw 
        }
    }

    Context "Get-Last-Version-From-Tag-On-Develop" {
        It "Get-Last-Version-From-Tag-On-Develop_withoutTag_ShouldReturnNull" {
            Test-Add-Commit
            Get-Last-Version-From-Tag-On-Develop | Should BeNullOrEmpty
        }

        It "Get-Last-Version-From-Tag-On-Develop_withTag_ShouldReturnTag" {
            Test-Add-Commit

            git tag -a "v1.0.0" -m "test"

            Get-Last-Version-From-Tag-On-Develop | Should Be "v1.0.0"
        }

        It "Get-Last-Version-From-Tag-On-Develop_withPatchTag_ShouldReturnNull" {
            Test-Add-Commit

            git tag -a "v1.0.1" -m "test"

            Get-Last-Version-From-Tag-On-Develop | Should BeNullOrEmpty
        }

        It "Get-Last-Version-From-Tag-On-Develop_withMultipleTags_ShouldReturnLastTag" {
            git tag -a "v1.0.0" -m "v1.0.0"

            Test-Add-Commit
            git tag -a "v1.1.0" -m "v1.1.0"

            Test-Add-Commit 
            git tag -a "v1.2.0" -m "v1.2.0"

            #Simulates Tag on support Branch
            Test-Add-Commit
            git tag -a "v1.2.1" -m "v1.2.1"
            
            Get-Last-Version-From-Tag-On-Develop | Should Be "v1.2.0"
        }

        It "Get-Last-Version-From-Tag-On-Develop_withPreVersion10_ShouldReturnPreVersion10" {
           Test-Add-Commit
           git tag -a "v1.0.0-alpha.10" -m "v1.0.0-alpha.10"

           Get-Last-Version-From-Tag-On-Develop | Should Be "v1.0.0-alpha.10"
        }
    }
}