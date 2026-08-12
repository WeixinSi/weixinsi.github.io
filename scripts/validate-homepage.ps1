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

function ConvertFrom-NavigationYamlScalar([string]$Value) {
    $scalar = ($Value -replace '\s+#.*$', '').Trim()
    if ($scalar -match '^"(.*)"$' -or $scalar -match "^'(.*)'$") {
        return $Matches[1]
    }
    return $scalar
}

function Get-MainNavigation([string]$Yaml) {
    if ($Yaml.Contains("`t")) {
        throw 'Navigation YAML must use spaces, not tabs.'
    }

    $lines = $Yaml -split "`r?`n"
    $mainMappings = [regex]::Matches($Yaml, '(?m)^(?<indent> *)main\s*:\s*(?:#.*)?$')
    if ($mainMappings.Count -ne 1) {
        throw "Expected exactly one main navigation mapping, found $($mainMappings.Count)."
    }

    $mainIndex = -1
    $mainIndent = 0
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $mainMatch = [regex]::Match($lines[$index], '^(?<indent> *)main\s*:\s*(?:#.*)?$')
        if ($mainMatch.Success) {
            $mainIndex = $index
            $mainIndent = $mainMatch.Groups['indent'].Value.Length
            break
        }
    }
    if ($mainIndex -lt 0) {
        throw 'Missing main navigation mapping.'
    }
    if ($mainIndent -ne 0) {
        throw 'The main navigation mapping must be a top-level YAML key.'
    }

    $items = [System.Collections.Generic.List[hashtable]]::new()
    $currentItem = $null
    $itemIndent = $mainIndent + 2
    $fieldIndent = $itemIndent + 2
    for ($index = $mainIndex + 1; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s*(?:#.*)?$') {
            continue
        }
        $indent = ([regex]::Match($line, '^ *')).Value.Length
        if ($indent -le $mainIndent) {
            break
        }

        $itemMatch = [regex]::Match($line, '^(?<indent> *)-\s+(?<key>[A-Za-z][A-Za-z0-9_-]*)\s*:\s*(?<value>.*)$')
        if ($itemMatch.Success) {
            $actualItemIndent = $itemMatch.Groups['indent'].Value.Length
            if ($actualItemIndent -ne $itemIndent) {
                throw "Main navigation list markers must be indented exactly $itemIndent spaces: $line"
            }
            $currentItem = @{}
            $items.Add($currentItem)
            $key = $itemMatch.Groups['key'].Value
            $currentItem[$key] = ConvertFrom-NavigationYamlScalar $itemMatch.Groups['value'].Value
            continue
        }

        $fieldMatch = [regex]::Match($line, '^(?<indent> +)(?<key>[A-Za-z][A-Za-z0-9_-]*)\s*:\s*(?<value>.*)$')
        if ($null -eq $currentItem -or -not $fieldMatch.Success) {
            throw "Unrecognized main navigation item: $line"
        }
        $actualFieldIndent = $fieldMatch.Groups['indent'].Value.Length
        if ($actualFieldIndent -ne $fieldIndent) {
            throw "Main navigation fields must be indented exactly $fieldIndent spaces: $line"
        }
        $key = $fieldMatch.Groups['key'].Value
        if ($currentItem.ContainsKey($key)) {
            throw "Duplicate navigation field: $key"
        }
        $currentItem[$key] = ConvertFrom-NavigationYamlScalar $fieldMatch.Groups['value'].Value
    }
    return $items
}

function Assert-NavigationContract([string]$Yaml) {
    $navigationItems = @(Get-MainNavigation $Yaml)
    $actualNavigation = foreach ($item in $navigationItems) {
        if ($item.Keys.Count -ne 2 -or -not $item.ContainsKey('title') -or -not $item.ContainsKey('url')) {
            throw 'Each main navigation item must contain only title and url fields.'
        }
        "$($item['title'])|$($item['url'])"
    }
    $expectedNavigation = @(
        'Home|/',
        'Team|/team/',
        'Publications|/publications/',
        'Talks|/talks/',
        'Teaching|/teaching/',
        'Gallery|/gallery/',
        'More|/more/'
    )
    if (($actualNavigation -join ',') -ne ($expectedNavigation -join ',')) {
        throw "Navigation mismatch: $($actualNavigation -join ', ')"
    }
}

function Get-Sha256Hex([string]$Text) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha256.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha256.Dispose()
    }
}

function Assert-PublicationsContract([string]$Publications) {
    $selectedHeadingCount = [regex]::Matches($Publications, '(?m)^## Selected Publications\s*$').Count
    if ($selectedHeadingCount -ne 1) {
        throw "Expected exactly one Selected Publications heading, found $selectedHeadingCount."
    }

    if ($Publications.Contains('<sup>*</sup>')) {
        throw 'Publication author markers must encode asterisks as &#42; so Kramdown does not corrupt the closing sup tag.'
    }

    $yearContracts = @(
        [pscustomobject]@{ Year = '2026'; Start = 1; Count = 9 },
        [pscustomobject]@{ Year = '2025'; Start = 10; Count = 20 },
        [pscustomobject]@{ Year = '2024'; Start = 30; Count = 10 },
        [pscustomobject]@{ Year = '2023'; Start = 40; Count = 1 },
        [pscustomobject]@{ Year = '2022'; Start = 41; Count = 6 },
        [pscustomobject]@{ Year = '2021'; Start = 47; Count = 6 },
        [pscustomobject]@{ Year = '2020'; Start = 53; Count = 1 },
        [pscustomobject]@{ Year = '2019'; Start = 54; Count = 6 },
        [pscustomobject]@{ Year = '2018'; Start = 60; Count = 2 },
        [pscustomobject]@{ Year = '2017'; Start = 62; Count = 2 },
        [pscustomobject]@{ Year = '2015'; Start = 64; Count = 1 },
        [pscustomobject]@{ Year = '2014'; Start = 65; Count = 1 },
        [pscustomobject]@{ Year = '2012'; Start = 66; Count = 1 },
        [pscustomobject]@{ Year = '2011'; Start = 67; Count = 1 }
    )

    $allYearHeadings = [regex]::Matches($Publications, '(?m)^(?<level>#{1,6})\s+(?<year>\d{4})\s*$')
    if ($allYearHeadings.Count -ne $yearContracts.Count) {
        throw "Expected $($yearContracts.Count) publication year headings, found $($allYearHeadings.Count)."
    }
    for ($index = 0; $index -lt $yearContracts.Count; $index++) {
        $heading = $allYearHeadings[$index]
        if ($heading.Groups['level'].Value -ne '###') {
            throw "Publication year $($heading.Groups['year'].Value) must use an h3 heading."
        }
        if ($heading.Groups['year'].Value -ne $yearContracts[$index].Year) {
            throw "Publication year order mismatch at position $($index + 1): expected $($yearContracts[$index].Year), found $($heading.Groups['year'].Value)."
        }
    }

    $lines = @($Publications -split '\r?\n')
    $listStartIalLines = @($lines | Where-Object { $_ -match '^\{:\s*start' })
    if ($listStartIalLines.Count -ne $yearContracts.Count) {
        throw "Expected exactly $($yearContracts.Count) ordered-list start IALs, found $($listStartIalLines.Count)."
    }
    foreach ($ialLine in $listStartIalLines) {
        if ($ialLine -notmatch '^\{: start="\d+"\}$') {
            throw "Malformed ordered-list start IAL: $ialLine"
        }
    }

    $selectedHeadingIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^## Selected Publications\s*$') {
            $selectedHeadingIndex = $index
            break
        }
    }

    $publicationBodies = [System.Collections.Generic.List[string]]::new()
    $uniqueBodies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $currentYearIndex = -1
    $currentYearEntryCount = 0
    $currentYearHasIal = $false
    $lastPublicationLineIndex = -1

    for ($lineIndex = $selectedHeadingIndex + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        $yearMatch = [regex]::Match($line, '^### (?<year>\d{4})\s*$')
        if ($yearMatch.Success) {
            if ($currentYearIndex -ge 0) {
                $previousContract = $yearContracts[$currentYearIndex]
                if ($currentYearEntryCount -ne $previousContract.Count) {
                    throw "Publication year $($previousContract.Year) must contain $($previousContract.Count) entries; found $currentYearEntryCount."
                }
                if (-not $currentYearHasIal) {
                    throw "Publication year $($previousContract.Year) is missing its ordered-list start IAL."
                }
            }

            $currentYearIndex++
            if ($currentYearIndex -ge $yearContracts.Count) {
                throw "Unexpected publication year heading: $($yearMatch.Groups['year'].Value)."
            }
            $currentContract = $yearContracts[$currentYearIndex]
            if ($yearMatch.Groups['year'].Value -ne $currentContract.Year) {
                throw "Publication year order mismatch: expected $($currentContract.Year), found $($yearMatch.Groups['year'].Value)."
            }
            $currentYearEntryCount = 0
            $currentYearHasIal = $false
            $lastPublicationLineIndex = -1
            continue
        }

        $publicationMatch = [regex]::Match($line, '^(?<number>\d+)\. (?<body>.+)$')
        if ($publicationMatch.Success) {
            if ($currentYearIndex -lt 0) {
                throw 'A publication entry appears before the first year heading.'
            }
            if ($currentYearHasIal) {
                throw "Publication year $($yearContracts[$currentYearIndex].Year) contains an entry after its list IAL."
            }

            $expectedNumber = $publicationBodies.Count + 1
            $actualNumber = [int]$publicationMatch.Groups['number'].Value
            if ($actualNumber -ne $expectedNumber) {
                throw "Publication numbering mismatch: expected $expectedNumber, found $actualNumber."
            }

            $body = $publicationMatch.Groups['body'].Value
            if (-not $uniqueBodies.Add($body)) {
                throw "Duplicate publication body at entry $actualNumber."
            }
            $publicationBodies.Add($body)
            $currentYearEntryCount++
            if ($currentYearEntryCount -gt $yearContracts[$currentYearIndex].Count) {
                throw "Publication year $($yearContracts[$currentYearIndex].Year) contains too many entries."
            }
            $lastPublicationLineIndex = $lineIndex
            continue
        }

        $ialMatch = [regex]::Match($line, '^\{: start="(?<start>\d+)"\}$')
        if ($ialMatch.Success) {
            if ($currentYearIndex -lt 0) {
                throw 'An ordered-list start IAL appears before the first publication year.'
            }
            if ($currentYearHasIal) {
                throw "Publication year $($yearContracts[$currentYearIndex].Year) has more than one ordered-list start IAL."
            }
            $currentContract = $yearContracts[$currentYearIndex]
            if ($currentYearEntryCount -ne $currentContract.Count) {
                throw "The ordered-list start IAL for $($currentContract.Year) must follow its final publication entry."
            }
            if ($lineIndex -ne $lastPublicationLineIndex + 1) {
                throw "The ordered-list start IAL for $($currentContract.Year) must immediately follow the list block."
            }
            $actualStart = [int]$ialMatch.Groups['start'].Value
            if ($actualStart -ne $currentContract.Start) {
                throw "Wrong ordered-list start for $($currentContract.Year): expected $($currentContract.Start), found $actualStart."
            }
            $currentYearHasIal = $true
        }
    }

    if ($currentYearIndex -ne $yearContracts.Count - 1) {
        throw "Expected $($yearContracts.Count) publication year sections, found $($currentYearIndex + 1)."
    }
    $finalContract = $yearContracts[$currentYearIndex]
    if ($currentYearEntryCount -ne $finalContract.Count) {
        throw "Publication year $($finalContract.Year) must contain $($finalContract.Count) entries; found $currentYearEntryCount."
    }
    if (-not $currentYearHasIal) {
        throw "Publication year $($finalContract.Year) is missing its ordered-list start IAL."
    }
    if ($publicationBodies.Count -ne 67) {
        throw "Expected 67 publication entries, found $($publicationBodies.Count)."
    }

    # Reviewed digest of the 67 complete, unnumbered entries after CRLF/LF normalization,
    # joined with LF and no terminal newline.
    # Any intentional publication addition or text/order change requires review and a digest update.
    $expectedPublicationDigest = 'b0b0676960c95848f0c75d4c991a24e672d19ff908aca7d82925424039d5cbe3'
    $actualPublicationDigest = Get-Sha256Hex ($publicationBodies -join "`n")
    if ($actualPublicationDigest -ne $expectedPublicationDigest) {
        throw "Publication content digest mismatch: expected $expectedPublicationDigest, found $actualPublicationDigest."
    }

    $scholarArrow = [regex]::Escape([string][char]0x2192)
    $scholarLinkPattern = '(?m)^\[View the complete publication record on Google Scholar ' + $scholarArrow + '\]\(https://scholar\.google\.com/citations\?user=E4efwTgAAAAJ\)[ \t]*\r?$'
    if ([regex]::Matches($Publications, $scholarLinkPattern).Count -ne 1) {
        throw 'Publications must contain exactly one approved Google Scholar record link.'
    }
}

function Assert-TeachingContract([string]$TeachingPage) {
    $frontMatter = [regex]::Match($TeachingPage, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)(?<body>.*)\z')
    if (-not $frontMatter.Success) {
        throw 'Teaching page is missing valid YAML front matter.'
    }
    $yaml = $frontMatter.Groups['yaml'].Value
    Assert-Match $yaml '(?m)^title:\s*"Teaching"\s*$' 'Teaching title must be exactly "Teaching".'
    Assert-Match $yaml '(?m)^permalink:\s*/teaching/\s*$' 'Teaching permalink must be /teaching/.'
    Assert-Match $yaml '(?m)^author_profile:\s*true\s*$' 'Teaching must enable the author profile.'

    $actualCourses = @(
        $frontMatter.Groups['body'].Value -split '\r?\n' |
            Where-Object { $_.Trim().Length -gt 0 }
    )
    $expectedCourses = @(
        ('- **Fall 2025:** FCAB335 Human' + [char]0x2013 + 'Computer Interaction and Virtual Reality'),
        '- **Spring 2026:** FCCA221 Data Structures and Algorithm Analysis',
        '- **Fall 2026:** FCCA511 Advanced Artificial Intelligence'
    )
    if (($actualCourses -join "`n") -ne ($expectedCourses -join "`n")) {
        throw "Teaching courses mismatch. Expected exactly: $($expectedCourses -join '; ')"
    }
}

function Assert-TeamContract([string]$TeamPage, [string]$TeamData, [string]$AcademicStyles) {
    $frontMatter = [regex]::Match($TeamPage, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)(?<body>.*)\z')
    if (-not $frontMatter.Success) {
        throw 'Team page is missing valid YAML front matter.'
    }
    $yaml = $frontMatter.Groups['yaml'].Value
    $body = $frontMatter.Groups['body'].Value
    Assert-Match $yaml '(?m)^title:\s*"Team"\s*$' 'Team title must be exactly "Team".'
    Assert-Match $yaml '(?m)^permalink:\s*/team/\s*$' 'Team permalink must be /team/.'
    Assert-Match $yaml '(?m)^author_profile:\s*true\s*$' 'Team must enable the author profile.'

    foreach ($requiredLoop in @('site.data.team.current_members', 'site.data.team.alumni_groups')) {
        Assert-Match $body ([regex]::Escape($requiredLoop)) "Team page must render $requiredLoop."
    }
    foreach ($requiredClass in @('team-intro', 'team-grid', 'team-card', 'team-alumni')) {
        Assert-Match $body ('class="[^"]*' + [regex]::Escape($requiredClass)) "Team page is missing the $requiredClass component."
        Assert-Match $AcademicStyles ('(?m)^\.' + [regex]::Escape($requiredClass) + '\b') "Team styles are missing .$requiredClass."
    }

    foreach ($heading in @('Ph.D. Students', 'Research Assistants & Interns', 'Graduated Students', 'Former Research Assistants & Interns')) {
        Assert-Match $TeamData ([regex]::Escape($heading)) "Team data is missing the $heading group."
    }
    $placeholderPortraitCount = [regex]::Matches($TeamData, '(?m)^\s+image:\s*"/images/bio-photo\.jpg"\s*$').Count
    if ($placeholderPortraitCount -lt 8) {
        throw "Expected at least 8 temporary team portraits, found $placeholderPortraitCount."
    }
    Assert-Match $AcademicStyles '(?m)^@media \(max-width: 600px\)' 'Team styles must include the mobile breakpoint.'

    $placeholderAsset = 'images/bio-photo.jpg'
    $trackedPlaceholderAsset = (& git -C $RepositoryRoot ls-files -- $placeholderAsset) -eq $placeholderAsset
    if (-not $trackedPlaceholderAsset) {
        throw "Team placeholder portrait must be tracked: $placeholderAsset"
    }
}

function Invoke-HomepageValidation {
    $navigation = Read-Utf8File '_data/navigation.yml'
    Assert-NavigationContract $navigation

    $requiredPages = [ordered]@{
        '_pages/about.md'        = '/'
        '_pages/team.md'         = '/team/'
        '_pages/publications.md' = '/publications/'
        '_pages/talks.md'        = '/talks/'
        '_pages/teaching.md'     = '/teaching/'
        '_pages/gallery.md'      = '/gallery/'
        '_pages/more.md'         = '/more/'
    }
    foreach ($entry in $requiredPages.GetEnumerator()) {
        $permalinkPattern = '(?m)^permalink:\s*' + [regex]::Escape($entry.Value) + '\s*$'
        Assert-Match (Read-Utf8File $entry.Key) $permalinkPattern "Wrong or missing permalink in $($entry.Key)"
    }
    Assert-Match (Read-Utf8File '_pages/research.md') '(?m)^permalink:\s*/research/\s*$' 'Wrong or missing permalink in _pages/research.md'

    $config = Read-Utf8File '_config.yml'
    Assert-Match $config '(?m)^\s*bio\s*:\s*"IEEE/CCF Senior Member"\s*$' 'The sidebar biography is not the requested membership line.'
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
    Assert-PublicationsContract $publications
    if ($publications -match '(?i)publication-filter|data-publication-filter') {
        throw 'Publication filters must be removed.'
    }
    if ($publications -match '(?i)<section\b|publication-group|data-publication-type') {
        throw 'Raw publication section grouping must be removed.'
    }
    if ($publications -match '(?mi)^#{1,6}\s+.*\b(?:Journal|Conference)\b.*$') {
        throw 'Journal and conference publication headings must be removed.'
    }

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
    if ($aboutPage -match 'Specially Appointed Full Professor') {
        throw 'Home must not mention the specially appointed full professor title.'
    }
    if ($aboutPage -match '(?ms)^- \[06/2024\] \*Depth-Driven Geometric Prompt Learning for Laparoscopic Liver\s+Landmark Detection\* was selected as an oral paper and a Best Paper\s+Award Finalist at MICCAI 2024\.\s*$') {
        throw 'Home still contains the removed June 2024 MICCAI news sentence.'
    }
    if ($aboutPage -match '(?m)^\[Email\]\(mailto:[^)]+\).+\[Google Scholar\]\([^)]+\).+\[Website\]\([^)]+\)\s*$') {
        throw 'Home must not contain an inline contact row.'
    }

    $morePage = Read-Utf8File '_pages/more.md'
    foreach ($heading in @('Teaching', 'Professional Appointments', 'Education', 'Contact')) {
        if ($morePage -match ('(?m)^##\s+' + [regex]::Escape($heading) + '\s*$')) {
            throw "More must not contain a $heading heading."
        }
    }

    $teachingPage = Read-Utf8File '_pages/teaching.md'
    Assert-TeachingContract $teachingPage

    $academicStyles = Read-Utf8File '_sass/layout/_academic-profile.scss'
    $teamPage = Read-Utf8File '_pages/team.md'
    $teamData = Read-Utf8File '_data/team.yml'
    Assert-TeamContract $teamPage $teamData $academicStyles
    $undefinedThemeVariable = [regex]::Match($academicStyles, '\$(?:background|text|link)-color\b')
    if ($undefinedThemeVariable.Success) {
        throw "Academic profile styles reference an undefined theme variable: $($undefinedThemeVariable.Value)"
    }
    $balancedDesktopLayoutPattern = '(?ms)^\s*\.page,\r?\n\s*\.archive\s*\{\r?\n\s*@include span\(9\.5 of 12 last\);\r?\n\s*@include prefix\(0\.5 of 12\);\r?\n\s*padding-right:\s*0;\r?\n\s*\}'
    Assert-Match $academicStyles $balancedDesktopLayoutPattern 'Desktop content must retain a half-column gutter and remove the inherited right padding.'

    Write-Host 'Homepage source validation passed.'
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-HomepageValidation
}
