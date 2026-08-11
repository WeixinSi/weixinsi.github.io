param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Utf8File([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $RelativePath"
    }
    return Get-Content -Raw -Encoding utf8 -LiteralPath $path
}

function Assert-Match([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

$navigation = Read-Utf8File '_data/navigation.yml'
$actualTitles = [regex]::Matches($navigation, '(?m)^\s*- title: "([^"]+)"') |
    ForEach-Object { $_.Groups[1].Value }
$expectedTitles = @('Home', 'Team', 'Research', 'Publications', 'Talks', 'Gallery', 'More')
if (($actualTitles -join '|') -ne ($expectedTitles -join '|')) {
    throw "Navigation mismatch: $($actualTitles -join ', ')"
}

$requiredPages = [ordered]@{
    '_pages/about.md'        = 'permalink:\s*/'
    '_pages/team.md'         = 'permalink:\s*/team/'
    '_pages/research.md'     = 'permalink:\s*/research/'
    '_pages/publications.md' = 'permalink:\s*/publications/'
    '_pages/talks.md'        = 'permalink:\s*/talks/'
    '_pages/gallery.md'      = 'permalink:\s*/gallery/'
    '_pages/more.md'         = 'permalink:\s*/more/'
}
foreach ($entry in $requiredPages.GetEnumerator()) {
    Assert-Match (Read-Utf8File $entry.Key) $entry.Value "Wrong or missing permalink in $($entry.Key)"
}

$config = Read-Utf8File '_config.yml'
Assert-Match $config '(?m)^\s*uri\s*:\s*"https://csce\.suat-sz\.edu\.cn/info/1011/1311\.htm"\s*$' 'Institutional Website is not configured.'
Assert-Match $config '(?m)^\s*googlescholar\s*:\s*"https://scholar\.google\.com/citations\?user=E4efwTgAAAAJ"\s*$' 'Google Scholar is not configured.'
if ($config -match '(?m)^\s*github\s*:\s*\S+') {
    throw 'GitHub must be blank in author metadata.'
}

$publicPagePaths = $requiredPages.Keys
$publicText = ($publicPagePaths | ForEach-Object { Read-Utf8File $_ }) -join "`n"
if ($publicText -match '(?i)github\.com|\[GitHub\]|>GitHub<') {
    throw 'A public page still exposes GitHub.'
}

$forbiddenRankingPattern = '(?i)CCF-[ABC]|JCR\s*Q[1-4]|CAS\s*Tier|Lancet\s+family'
if ($publicText -match $forbiddenRankingPattern) {
    throw "A publication ranking label remains: $($Matches[0])"
}

$publications = Read-Utf8File '_pages/publications.md'
$journalBlock = [regex]::Match($publications, '(?s)## Journal Articles\s+(.*?)\s+## Conference Papers').Groups[1].Value
$conferenceBlock = [regex]::Match($publications, '(?s)## Conference Papers\s+(.*?)(?:\s+</section>|\s+<script)').Groups[1].Value
$journalCount = [regex]::Matches($journalBlock, '(?m)^\d+\. ').Count
$conferenceCount = [regex]::Matches($conferenceBlock, '(?m)^\d+\. ').Count
if ($journalCount -ne 51) { throw "Expected 51 journal articles, found $journalCount." }
if ($conferenceCount -ne 16) { throw "Expected 16 conference papers, found $conferenceCount." }

$gallery = Read-Utf8File '_pages/gallery.md'
foreach ($heading in @('Distinguished Visitors', 'Publicity', 'Academic Events & Activities')) {
    Assert-Match $gallery ([regex]::Escape($heading)) "Gallery heading missing: $heading"
}

$home = Read-Utf8File '_pages/about.md'
if ($home -match '(?m)^##\s+Biography\s*$') {
    throw 'Home biography must not have a Biography heading.'
}
Assert-Match $home 'Specially Appointed Full Professor' 'The specially appointed full professor title is missing.'

Write-Host 'Homepage source validation passed.'
