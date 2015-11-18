. $PSScriptRoot"\..\semver_functions.ps1"

Describe "semver_functions" {

    Context "Get-Possible-Next-Versions" {
        It "Get-Possible-Next-Versions_WithAlpha_ShouldReturnArray" {
            $Version = "1.2.0-alpha.4"
            $NextVersions = "1.2.0-alpha.5", "1.2.0-beta.1", "1.2.0-rc.1", "1.3.0", "2.0.0"

            Get-Possible-Next-Versions $Version | Should Be $NextVersions
        }

        It "Get-Possible-Next-Versions_WithBeta_ShouldReturnArray" {
            $Version = "1.2.0-beta.2"
            $NextVersions = "1.2.0-beta.3", "1.2.0-rc.1", "1.3.0", "2.0.0"

            Get-Possible-Next-Versions $Version | Should Be $NextVersions
        }

        It "Get-Possible-Next-Versions_WithRc_ShouldReturnArray" {
            $Version = "1.2.0-rc.4"
            $NextVersions = "1.2.0-rc.5", "1.3.0", "2.0.0"

            Get-Possible-Next-Versions $Version | Should Be $NextVersions
        }

        It "Get-Possible-Next-Versions_WithoutPre_ShouldReturnArray" {
            $Version = "1.2.0"
            $NextVersions = "1.2.0-alpha.1", "1.2.0-rc.1", "1.3.0", "2.0.0"

            Get-Possible-Next-Versions $Version | Should Be $NextVersions
        }

        It "Get-Possible-Next-Versions_WithPreVersion10_ShouldReturnArray" {
            $version = "1.0.0-alpha.10"
            $NextVersions = "1.0.0-alpha.11", "1.0.0-beta.1", "1.0.0-rc.1", "1.1.0", "2.0.0"

            Get-Possible-Next-Versions $Version | Should Be $NextVersions
        }

        It "Get-Possible-Next-Versions_WithInvalidVersion_ShouldThrowException" {
            {Get-Possible-Next-Versions "completelyWrongVersion" } | Should Throw "Your version 'completelyWrongVersion' does not have a valid format (e.g. 1.2.3-alpha.1)"
            {Get-Possible-Next-Versions "1.2.3.4" } | Should Throw "Your version '1.2.3.4' does not have a valid format (e.g. 1.2.3-alpha.1)"            
            {Get-Possible-Next-Versions "1.2.3-somethinginvalid.4" } | Should Throw "Your version '1.2.3-somethinginvalid.4' does not have a valid format (e.g. 1.2.3-alpha.1)"            
            {Get-Possible-Next-Versions "1.2.3.alpha-4" } | Should Throw "Your version '1.2.3.alpha-4' does not have a valid format (e.g. 1.2.3-alpha.1)"            
            {Get-Possible-Next-Versions "1.2.3.rc.4" } | Should Throw "Your version '1.2.3.rc.4' does not have a valid format (e.g. 1.2.3-alpha.1)"            
        }
    }
}