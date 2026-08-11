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

function Assert-FrontMatterPublishedFalse([string]$RelativePath) {
    $content = Read-Utf8File $RelativePath
    $frontMatter = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)')
    if (-not $frontMatter.Success) {
        throw "Missing YAML front matter in $RelativePath"
    }
    Assert-Match $frontMatter.Groups[1].Value '(?m)^published:\s*false\s*$' "published: false is missing from $RelativePath"
}

$navigation = Read-Utf8File '_data/navigation.yml'
$actualNavigation = [regex]::Matches($navigation, '(?m)^\s*- title:\s*"([^"]+)"\s*\r?\n\s+url:\s*(\S+)\s*$') |
    ForEach-Object { "$($_.Groups[1].Value)|$($_.Groups[2].Value)" }
$expectedNavigation = @(
    'Home|/',
    'Team|/team/',
    'Research|/research/',
    'Publications|/publications/',
    'Talks|/talks/',
    'Gallery|/gallery/',
    'More|/more/'
)
if (($actualNavigation -join ',') -ne ($expectedNavigation -join ',')) {
    throw "Navigation mismatch: $($actualNavigation -join ', ')"
}

$requiredPages = [ordered]@{
    '_pages/about.md'        = '/'
    '_pages/team.md'         = '/team/'
    '_pages/research.md'     = '/research/'
    '_pages/publications.md' = '/publications/'
    '_pages/talks.md'        = '/talks/'
    '_pages/gallery.md'      = '/gallery/'
    '_pages/more.md'         = '/more/'
}
foreach ($entry in $requiredPages.GetEnumerator()) {
    $permalinkPattern = '(?m)^permalink:\s*' + [regex]::Escape($entry.Value) + '\s*$'
    Assert-Match (Read-Utf8File $entry.Key) $permalinkPattern "Wrong or missing permalink in $($entry.Key)"
}

$config = Read-Utf8File '_config.yml'
Assert-Match $config '(?m)^\s*uri\s*:\s*"https://csce\.suat-sz\.edu\.cn/info/1011/1311\.htm"\s*$' 'Institutional Website is not configured.'
Assert-Match $config '(?m)^\s*googlescholar\s*:\s*"https://scholar\.google\.com/citations\?user=E4efwTgAAAAJ"\s*$' 'Google Scholar is not configured.'
if ($config -match '(?m)^\s*github\s*:[^\S\r\n]*\S+') {
    throw 'GitHub must be blank in author metadata.'
}
foreach ($collectionName in @('teaching', 'publications', 'portfolio', 'talks', 'gallery')) {
    $collectionPattern = '(?m)^  ' + [regex]::Escape($collectionName) + ':\r?\n    output: false\s*$'
    Assert-Match $config $collectionPattern "Collection output must be false: $collectionName"
}

$hiddenContentPaths = @(
    '_pages/archive-layout-with-content.md',
    '_pages/category-archive.html',
    '_pages/collection-archive.html',
    '_pages/cv-json.md',
    '_pages/cv.md',
    '_pages/markdown.md',
    '_pages/non-menu-page.md',
    '_pages/page-archive.html',
    '_pages/portfolio.html',
    '_pages/tag-archive.html',
    '_pages/talkmap.html',
    '_pages/teaching.html',
    '_pages/year-archive.html',
    '_posts/2012-08-14-blog-post-1.md',
    '_posts/2013-08-14-blog-post-2.md',
    '_posts/2014-08-14-blog-post-3.md',
    '_posts/2015-08-14-blog-post-4.md',
    '_posts/2199-01-01-future-post.md'
)
foreach ($hiddenContentPath in $hiddenContentPaths) {
    Assert-FrontMatterPublishedFalse $hiddenContentPath
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

$aboutPage = Read-Utf8File '_pages/about.md'
$cvAssetPath = 'files/weixin-si-cv.pdf'
$trackedCvAsset = (& git -C $RepositoryRoot ls-files -- $cvAssetPath) -eq $cvAssetPath
if ($aboutPage -match [regex]::Escape('/files/weixin-si-cv.pdf') -and -not $trackedCvAsset) {
    throw 'Home links to an untracked CV asset: /files/weixin-si-cv.pdf'
}
if ($aboutPage -match '(?m)^##\s+Biography\s*$') {
    throw 'Home biography must not have a Biography heading.'
}
Assert-Match $aboutPage 'Specially Appointed Full Professor' 'The specially appointed full professor title is missing.'

Write-Host 'Homepage source validation passed.'
