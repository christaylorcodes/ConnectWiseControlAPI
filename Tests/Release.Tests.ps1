# Tests for Build/Get-ReleaseInfo.ps1, the check that runs before the release workflow builds or publishes anything.
# They use a temporary manifest and changelog and never contact the PowerShell Gallery.

BeforeAll {
    $Script:ReleaseInfo = Join-Path (Split-Path -Parent $PSScriptRoot) 'Build/Get-ReleaseInfo.ps1'
    $Script:TestManifest = Join-Path $TestDrive 'Sample.psd1'
    $Script:TestChangelog = Join-Path $TestDrive 'CHANGELOG.md'

    function Set-TestRelease {
        param([string]$Version = '1.2.3', [string[]]$Changelog)
        Set-Content -Path $Script:TestManifest -Value "@{ ModuleVersion = '$Version' }"
        Set-Content -Path $Script:TestChangelog -Value $Changelog
    }

    function Get-TestReleaseInfo {
        param([hashtable]$With = @{})
        & $Script:ReleaseInfo -ManifestPath $Script:TestManifest -ChangelogPath $Script:TestChangelog -SkipGalleryCheck @With
    }

    $Script:ReleasedChangelog = @(
        '# Changelog'
        ''
        '## [Unreleased]'
        ''
        '## [1.2.3] - 2026-01-31'
        ''
        '### Added'
        ''
        '- New thing'
        ''
        '## [1.2.2] - 2025-12-01'
        ''
        '- Old thing'
        ''
        '[Unreleased]: https://example.com/compare/v1.2.3...HEAD'
        '[1.2.3]: https://example.com/compare/v1.2.2...v1.2.3'
    )
    $Script:UnreleasedChangelog = @(
        '# Changelog'
        ''
        '## [Unreleased]'
        ''
        '- Coming soon'
        ''
        '## [1.2.2] - 2025-12-01'
        ''
        '- Old thing'
    )
}

Describe 'Build/Get-ReleaseInfo.ps1' {
    Context 'a tagged release' {
        BeforeEach { Set-TestRelease -Changelog $Script:ReleasedChangelog }

        It 'returns the version and only that version''s notes' {
            $Info = Get-TestReleaseInfo -With @{ Tag = 'v1.2.3' }
            $Info.ModuleName | Should -Be 'Sample'
            $Info.Version | Should -Be '1.2.3'
            $Info.Tag | Should -Be 'v1.2.3'
            $Info.DryRun | Should -BeFalse
            $Info.Notes | Should -Match '^### Added'
            $Info.Notes | Should -Match 'New thing$'
            $Info.Notes | Should -Not -Match 'Old thing|example\.com'
        }

        It 'writes the notes to -NotesPath' {
            $NotesPath = Join-Path $TestDrive 'notes/release-notes.md'
            Get-TestReleaseInfo -With @{ Tag = 'v1.2.3'; NotesPath = $NotesPath } | Out-Null
            (Get-Content -Path $NotesPath -Raw).Trim() | Should -Match '^### Added[\s\S]*New thing$'
        }

        It 'fails when the tag does not match the manifest version' {
            { Get-TestReleaseInfo -With @{ Tag = 'v1.2.4' } } | Should -Throw '*does not match ModuleVersion*'
        }

        It 'fails for a tag that is not v<major>.<minor>.<patch>: <Tag>' -ForEach @(
            @{ Tag = '1.2.3' }, @{ Tag = 'v1.2' }, @{ Tag = 'v1.2.3-beta' }, @{ Tag = 'v1.2.3.0' }
        ) {
            { Get-TestReleaseInfo -With @{ Tag = $Tag } } | Should -Throw '*must look like v1.2.3*'
        }

        It 'refuses -AllowUnreleased together with -Tag' {
            { Get-TestReleaseInfo -With @{ Tag = 'v1.2.3'; AllowUnreleased = $true } } | Should -Throw '*dry runs only*'
        }
    }

    Context 'a changelog that is not ready' {
        It 'fails when the version has no section' {
            Set-TestRelease -Changelog $Script:UnreleasedChangelog
            { Get-TestReleaseInfo -With @{ Tag = 'v1.2.3' } } | Should -Throw '*has no*section*'
        }

        It 'fails when the heading has no date' {
            Set-TestRelease -Changelog ($Script:ReleasedChangelog -replace '^## \[1\.2\.3\].*$', '## [1.2.3]')
            { Get-TestReleaseInfo -With @{ Tag = 'v1.2.3' } } | Should -Throw '*needs a date*'
        }

        It 'fails when the section is empty' {
            Set-TestRelease -Changelog '## [1.2.3] - 2026-01-31', '', '## [1.2.2] - 2025-12-01', '', '- Old thing'
            { Get-TestReleaseInfo -With @{ Tag = 'v1.2.3' } } | Should -Throw '*is empty*'
        }

        It 'fails when the manifest version does not have three parts' {
            Set-TestRelease -Version '1.2.3.0' -Changelog $Script:ReleasedChangelog
            { Get-TestReleaseInfo } | Should -Throw '*three parts*'
        }
    }

    Context 'a dry run (no tag)' {
        It 'uses the version section when it exists' {
            Set-TestRelease -Changelog $Script:ReleasedChangelog
            $Info = Get-TestReleaseInfo
            $Info.DryRun | Should -BeTrue
            $Info.NotesSource | Should -Be '1.2.3'
        }

        It 'falls back to [Unreleased] only with -AllowUnreleased' {
            Set-TestRelease -Changelog $Script:UnreleasedChangelog
            { Get-TestReleaseInfo } | Should -Throw '*has no*section*'
            $Info = Get-TestReleaseInfo -With @{ AllowUnreleased = $true }
            $Info.NotesSource | Should -Be 'Unreleased'
            $Info.Notes | Should -Be '- Coming soon'
        }
    }

    Context 'this repository' {
        It 'is releasable as a dry run' {
            $Info = & $Script:ReleaseInfo -AllowUnreleased -SkipGalleryCheck
            $Info.Version | Should -Match '^\d+\.\d+\.\d+$'
            $Info.Notes | Should -Not -BeNullOrEmpty
        }
    }
}
