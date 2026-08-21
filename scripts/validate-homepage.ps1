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
        [pscustomobject]@{ Year = '2018'; Start = 60; Count = 2 }
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
    if ($publicationBodies.Count -ne 61) {
        throw "Expected 61 publication entries, found $($publicationBodies.Count)."
    }

    # Reviewed digest of the 61 complete, unnumbered entries after CRLF/LF normalization,
    # joined with LF and no terminal newline.
    # Any intentional publication addition or text/order change requires review and a digest update.
    $expectedPublicationDigest = 'd0cdcc449845efb5ee2f58ae9d3863c5a8d7f1118226e2bc3a43350977d42b8f'
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

    foreach ($requiredLoop in @('site.data.team.current_members', 'site.data.team.alumni.groups')) {
        Assert-Match $body ([regex]::Escape($requiredLoop)) "Team page must render $requiredLoop."
    }
    Assert-Match $body "member\.image\s*==\s*'/images/bio-photo\.jpg'" 'Team portrait alt text must distinguish placeholder images from confirmed portraits.'
    Assert-Match $body 'Portrait of' 'Confirmed Team portraits must use factual alt text.'
    Assert-Match $body '(?s)<div class="team-card__heading">\s*<h3>.*?</h3>\s*\{%\s*if\s+member\.role\s*%\}\s*<span class="team-card__role">\{\{\s*member\.role\s*\}\}</span>\s*\{%\s*endif\s*%\}\s*</div>' 'Team member names and dates must share one compact heading row.'
    if ($body -match '<p class="team-card__role">') {
        throw 'Team membership dates must not render as a separate paragraph.'
    }
    foreach ($requiredClass in @('team-intro', 'team-grid', 'team-card', 'team-card__heading')) {
        Assert-Match $body ('class="[^"]*' + [regex]::Escape($requiredClass)) "Team page is missing the $requiredClass component."
        Assert-Match $AcademicStyles ('(?m)^\.' + [regex]::Escape($requiredClass) + '\b') "Team styles are missing .$requiredClass."
    }
    foreach ($requiredAlumniClass in @('team-alumni', 'team-alumni__group', 'team-alumni__list')) {
        Assert-Match $body ('class="[^"]*' + [regex]::Escape($requiredAlumniClass)) "Team page is missing the $requiredAlumniClass component."
        Assert-Match $AcademicStyles ('(?m)^\.' + [regex]::Escape($requiredAlumniClass) + '\b') "Team styles are missing .$requiredAlumniClass."
    }
    if ($body.IndexOf('class="team-alumni"', [System.StringComparison]::Ordinal) -lt $body.IndexOf('site.data.team.current_members', [System.StringComparison]::Ordinal)) {
        throw 'The Alumni section must appear after current team members.'
    }

    foreach ($heading in @('Research Assistant Professor', 'Postdoctoral Fellows', 'Ph.D. Students', 'Research Assistants', "Master's Students")) {
        Assert-Match $TeamData ([regex]::Escape($heading)) "Team data is missing the $heading group."
    }
    foreach ($memberName in @('Yingying Wang', 'Jiawen Yang', 'Peiji Li', 'Congyu Tian', 'Haipeng Wang', 'Incoming Postdoctoral Fellow', 'Yufan Ding', 'Jincai Huang', 'Yixin Wang', 'Ziqiao Qu', 'Yang Liu', 'Jiaxin Ni', 'Shunduo Zhang', 'Zili Li')) {
        Assert-Match $TeamData ([regex]::Escape($memberName)) "Team data is missing $memberName."
    }
    $membershipYear2025 = '2025' + [char]0x2013
    $membershipYear2026 = '2026' + [char]0x2013
    $institutionSeparator = [char]0x2013
    $buaaSuatJointProgram = "BUAA${institutionSeparator}SUAT Joint Training Program"
    $fduSuatJointProgram = "FDU${institutionSeparator}SUAT Joint Training Program"
    $sustechSuatJointProgram = "SUSTech${institutionSeparator}SUAT Joint Training Program"
    foreach ($requiredTeamFact in @($membershipYear2025, $membershipYear2026, 'SUAT', 'BUAA', 'FDU', 'SUSTech', $buaaSuatJointProgram, $fduSuatJointProgram, $sustechSuatJointProgram)) {
        Assert-Match $TeamData ([regex]::Escape($requiredTeamFact)) "Team data is missing required information: $requiredTeamFact"
    }
    $expectedTeamFactCounts = [ordered]@{}
    $expectedTeamFactCounts[('role: "' + $membershipYear2025 + '"')] = 11
    $expectedTeamFactCounts[('role: "' + $membershipYear2026 + '"')] = 1
    $expectedTeamFactCounts[$sustechSuatJointProgram] = 8
    foreach ($teamFact in $expectedTeamFactCounts.GetEnumerator()) {
        $actualCount = [regex]::Matches($TeamData, [regex]::Escape($teamFact.Key)).Count
        if ($actualCount -ne $teamFact.Value) {
            throw "Expected $($teamFact.Value) occurrences of '$($teamFact.Key)', found $actualCount."
        }
    }
    foreach ($obsoletePlaceholder in @('Member Name 01', 'Alumnus Name 01', 'site.data.team.alumni_groups', 'Member information to be updated', 'Full name to be confirmed')) {
        if ($TeamData -match [regex]::Escape($obsoletePlaceholder) -or $body -match [regex]::Escape($obsoletePlaceholder)) {
            throw "Team still contains obsolete placeholder content: $obsoletePlaceholder"
        }
    }
    foreach ($expandedInstitutionName in @('Shenzhen University of Advanced Technology', 'Beihang University', 'Fudan University', 'Southern University of Science and Technology')) {
        if ($TeamData -match [regex]::Escape($expandedInstitutionName)) {
            throw "Team affiliations must use institution abbreviations only: $expandedInstitutionName"
        }
    }
    foreach ($redundantRole in @('Research Assistant Professor', 'Ph.D. Student', 'Research Assistant', 'Incoming Postdoctoral Fellow', "Master's Student")) {
        if ($TeamData -match ('(?m)^\s+role:\s*"[^"\r\n]*' + [regex]::Escape($redundantRole))) {
            throw "Team member roles must not repeat group headings: $redundantRole"
        }
    }
    $ruotongInternPeriod = '2019' + [char]0x2013 + '2022 PhD'
    $linxiaInternPeriod = '2021' + [char]0x2013 + '2023 PhD'
    $zehuaInternPeriod = '2022' + [char]0x2013 + '2025 RA'
    foreach ($requiredInternFact in @('title: "Alumni"', 'id: interns', 'title: "Interns"', 'name: "Ruotong Li"', 'name: "Linxia Xiao"', 'name: "Zehua Liu"', ('period: "' + $ruotongInternPeriod + '"'), ('period: "' + $linxiaInternPeriod + '"'), ('period: "' + $zehuaInternPeriod + '"'), 'current: "Current: Assistant Researcher at Peng Cheng Laboratory"', 'current: "Current: Associate Researcher at SIAT"', 'current: "Current: PhD at BUAA"')) {
        Assert-Match $TeamData ([regex]::Escape($requiredInternFact)) "Team Interns data is missing required information: $requiredInternFact"
    }
    if ($TeamData -match [regex]::Escape('Former Team Members')) {
        throw 'Team still contains the former Former Team Members heading.'
    }
    $alumniMemberCount = [regex]::Matches($TeamData, '(?m)^\s{8}- name:\s*"').Count
    if ($alumniMemberCount -ne 3) {
        throw "Expected exactly 3 Intern entries, found $alumniMemberCount."
    }
    $expectedMemberPortraits = [ordered]@{
        'Yingying Wang' = '/images/wyy.jpg'
        'Jiawen Yang' = '/images/yjw.jpg'
        'Peiji Li' = '/images/lpj.jpg'
        'Congyu Tian' = '/images/tcy.jpg'
        'Haipeng Wang' = '/images/whp.jpg'
        'Yufan Ding' = '/images/dyf.jpg'
        'Jincai Huang' = '/images/hjc.jpg'
        'Yixin Wang' = '/images/wyx.jpg'
        'Ziqiao Qu' = '/images/qzq.jpg'
        'Yang Liu' = '/images/ly.jpg'
        'Jiaxin Ni' = '/images/njx.jpg'
        'Shunduo Zhang' = '/images/zsd.jpg'
        'Zili Li' = '/images/lzl.jpg'
    }
    foreach ($portrait in $expectedMemberPortraits.GetEnumerator()) {
        $portraitPattern = '(?ms)^\s{6}- name:\s*"' + [regex]::Escape($portrait.Key) + '"\s*\r?\n(?:(?!^\s{6}- name:).)*?^\s{8}image:\s*"' + [regex]::Escape($portrait.Value) + '"\s*$'
        Assert-Match $TeamData $portraitPattern "Team portrait mismatch for $($portrait.Key): expected $($portrait.Value)"
    }
    $placeholderPortraitCount = [regex]::Matches($TeamData, '(?m)^\s+image:\s*"/images/bio-photo\.jpg"\s*$').Count
    if ($placeholderPortraitCount -ne 1) {
        throw "Expected exactly 1 temporary team portrait, found $placeholderPortraitCount."
    }
    Assert-Match $AcademicStyles '(?ms)^\.team-grid\s*\{[^}]*grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)\s*;' 'Team desktop layout must use four compact columns.'
    Assert-Match $AcademicStyles '(?ms)^\.team-card\s*\{[^}]*border:\s*0\s*;[^}]*box-shadow:\s*none\s*;' 'Team member blocks must not use the former large card treatment.'
    Assert-Match $AcademicStyles '(?ms)^\.team-card__portrait\s*\{[^}]*max-width:\s*8\.5rem\s*;[^}]*aspect-ratio:\s*5\s*/\s*7\s*;[^}]*object-fit:\s*cover\s*;[^}]*object-position:\s*center\s+top\s*;[^}]*border-radius:\s*0\.15rem\s*;' 'Team portraits must use the standard one-inch photo ratio with head-safe cropping.'
    Assert-Match $AcademicStyles '(?ms)^\.team-card__body\s*\{[^}]*padding:\s*0\.5rem\s+0\.1rem\s+0\s*;' 'Team card text spacing must use the reduced compact size.'
    Assert-Match $AcademicStyles '(?ms)^\.team-card__heading\s*\{[^}]*display:\s*flex\s*;[^}]*align-items:\s*baseline\s*;[^}]*justify-content:\s*center\s*;[^}]*flex-wrap:\s*wrap\s*;' 'Team member names and dates must use a centered baseline-aligned flex row.'
    Assert-Match $AcademicStyles '(?ms)^\.team-card__role\s*\{[^}]*color:\s*var\(--global-text-color-light\)\s*;[^}]*font-size:\s*0\.72em\s*;[^}]*white-space:\s*nowrap\s*;' 'Team membership dates must use compact secondary typography.'
    Assert-Match $AcademicStyles '(?ms)^\.team-alumni__list\s*\{[^}]*display:\s*block\s*;[^}]*padding-left:\s*1\.25rem\s*;' 'Team Alumni must use a compact single-column text list.'
    Assert-Match $AcademicStyles '(?ms)^@include breakpoint\(\$large\)\s*\{.*?\.sidebar\s*\{[^}]*@include span\(2\.5 of 12\)\s*;[^}]*max-width:\s*\$sidebar-link-max-width\s*;' 'Desktop author sidebar must retain its theme width cap so it cannot overlap main content on wide screens.'
    Assert-Match $AcademicStyles '(?ms)^@include breakpoint\(\$large\)\s*\{.*?\.author__avatar img\s*\{[^}]*max-width:\s*12rem\s*;.*?\.sidebar \.author__name\s*\{[^}]*font-size:\s*1\.2rem\s*;[^}]*line-height:\s*1\.25\s*;.*?\.sidebar \.author__bio\s*\{[^}]*font-size:\s*0\.9rem\s*;[^}]*line-height:\s*1\.5\s*;.*?\.sidebar \.author__urls li,\s*\.sidebar \.author__urls a\s*\{[^}]*font-size:\s*0\.9rem\s*;[^}]*line-height:\s*1\.45\s*;' 'Desktop author profile must be visibly larger than Team member profiles.'
    Assert-Match $AcademicStyles '(?ms)^@media \(max-width: 600px\)\s*\{.*?\.team-grid\s*\{\s*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)\s*;' 'Team mobile layout must retain two compact columns.'
    Assert-Match $AcademicStyles '(?ms)^@media \(min-width: 601px\) and \(max-width: 960px\)\s*\{.*?\.team-grid\s*\{\s*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)\s*;' 'Team tablet layout must use two compact columns.'

    $placeholderAsset = 'images/bio-photo.jpg'
    $trackedPlaceholderAsset = (& git -C $RepositoryRoot ls-files -- $placeholderAsset) -eq $placeholderAsset
    if (-not $trackedPlaceholderAsset) {
        throw "Team placeholder portrait must be tracked: $placeholderAsset"
    }
    foreach ($portraitAsset in @('images/wyy.jpg', 'images/yjw.jpg', 'images/lpj.jpg', 'images/tcy.jpg', 'images/whp.jpg', 'images/dyf.jpg', 'images/hjc.jpg', 'images/wyx.jpg', 'images/qzq.jpg', 'images/ly.jpg', 'images/njx.jpg', 'images/zsd.jpg', 'images/lzl.jpg')) {
        $trackedPortraitAsset = (& git -C $RepositoryRoot ls-files -- $portraitAsset) -eq $portraitAsset
        if (-not $trackedPortraitAsset) {
            throw "Team portrait must be tracked: $portraitAsset"
        }
    }
}

function Invoke-HomepageValidation {
    $navigation = Read-Utf8File '_data/navigation.yml'
    Assert-NavigationContract $navigation

    $navigationStyles = Read-Utf8File '_sass/layout/_navigation.scss'
    if ($navigationStyles -match '(?ms)\.visible-links\s*\{.*?&:first-child\s*\{(?:(?!\r?\n\s+a\s*\{).)*font-weight:\s*(?:bold|[6-9]00)\s*;') {
        throw 'The first navigation item must not be permanently bold.'
    }
    $mastheadStyles = Read-Utf8File '_sass/layout/_masthead.scss'
    Assert-Match $mastheadStyles '(?ms)\.masthead__menu-item\.selected a\s*\{[^}]*font-weight:\s*700\s*;' 'Only the selected navigation item must use bold typography.'
    $mastheadTemplate = Read-Utf8File '_includes/masthead.html'
    Assert-Match $mastheadTemplate "(?ms)if link\.url == '/'\s*%}.*?page\.url == '/' or page\.url == '/index\.html'.*?masthead__menu-item\{% if link_selected %\} selected" 'The masthead must select Home only on the home page.'

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
    Assert-Match $config '(?m)^\s*avatar\s*:\s*"swx\.jpg"\s*$' 'The sidebar avatar must use swx.jpg.'
    $avatarAsset = 'images/swx.jpg'
    $trackedAvatarAsset = (& git -C $RepositoryRoot ls-files -- $avatarAsset) -eq $avatarAsset
    if (-not $trackedAvatarAsset) {
        throw "Sidebar avatar must be tracked: $avatarAsset"
    }
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
    Assert-Match $gallery '(?m)^hide_title:\s*true\s*$' 'Gallery must hide its repeated visible page title.'
    foreach ($heading in @('Distinguished Visitors', 'Publicity', 'Academic Events & Activities')) {
        Assert-Match $gallery ([regex]::Escape($heading)) "Gallery heading missing: $heading"
    }
    foreach ($gallerySection in @(
        @{ Category = 'visitors'; Title = 'Distinguished Visitors' },
        @{ Category = 'publicity'; Title = 'Publicity' },
        @{ Category = 'activities'; Title = 'Academic Events & Activities' }
    )) {
        $sectionIncludePattern = '\{%\s*include\s+gallery-section\.html\s+category="' + [regex]::Escape($gallerySection.Category) + '"\s+title="' + [regex]::Escape($gallerySection.Title) + '"\s*%\}'
        Assert-Match $gallery $sectionIncludePattern "Gallery must pass the heading into its $($gallerySection.Category) card section."
    }
    $gallerySectionInclude = Read-Utf8File '_includes/gallery-section.html'
    Assert-Match $gallerySectionInclude '(?ms)\{%\s*if\s+gallery_items\.size\s*>\s*0\s*%\}.*?<section class="academic-gallery__group".*?<h2[^>]*class="academic-gallery__heading"[^>]*>\{\{\s*include\.title\s*\}\}</h2>.*?<div class="academic-gallery__section academic-gallery__section--\{\{\s*include\.category\s*\}\}">' 'Gallery must hide empty groups and mark each populated card grid with its category.'
    Assert-Match $gallerySectionInclude '(?ms)\{%\s*include\s+gallery\s+images=item\.images\s+class="academic-gallery__media"\s*%\}' 'Gallery cards must mark their media region for responsive image sizing.'
    Assert-Match $gallerySectionInclude '(?ms)<div class="academic-gallery__body">.*?<h3 class="academic-gallery__title">.*?<div class="academic-gallery__description">.*?<p class="academic-gallery__meta">' 'Gallery cards must separate title, description, and footer metadata inside a card body.'
    $singleLayout = Read-Utf8File '_layouts/single.html'
    Assert-Match $singleLayout '(?ms)<h1 class="page__title\{%\s*if\s+page\.hide_title\s*%\}\s+screen-reader-text\{%\s*endif\s*%\}" itemprop="headline">' 'Single pages must support visually hiding an opted-in page title without removing document metadata.'

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
    foreach ($removedBiographyPhrase in @('His research work has received recognition at', 'Organizing Chair for ChinaVR 2026')) {
        if ($aboutPage -match [regex]::Escape($removedBiographyPhrase)) {
            throw "Home still contains removed biography text: $removedBiographyPhrase"
        }
    }
    if ($aboutPage -match '(?ms)^- \[06/2024\] \*Depth-Driven Geometric Prompt Learning for Laparoscopic Liver\s+Landmark Detection\* was selected as an oral paper and a Best Paper\s+Award Finalist at MICCAI 2024\.\s*$') {
        throw 'Home still contains the removed June 2024 MICCAI news sentence.'
    }
    if ($aboutPage -match '(?m)^\[Email\]\(mailto:[^)]+\).+\[Google Scholar\]\([^)]+\).+\[Website\]\([^)]+\)\s*$') {
        throw 'Home must not contain an inline contact row.'
    }
    $recruitmentNote = 'Note: I am looking for self-motivated Postdoc/PhD/RA/Interns. Feel free to drop me an email with your CV.'
    $recruitmentPattern = '(?m)^<p class="recruitment-note">' + [regex]::Escape($recruitmentNote) + '</p>\s*$'
    if ([regex]::Matches($aboutPage, $recruitmentPattern).Count -ne 1) {
        throw 'Home must contain exactly one approved recruitment note below the biography.'
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
    Assert-Match $academicStyles '(?ms)^\.recruitment-note\s*\{[^}]*color:\s*#c62828\s*;' 'Recruitment note must use the approved red text color.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__heading\s*\{[^}]*text-align:\s*center\s*;[^}]*color:\s*var\(--global-link-color\)\s*;' 'Gallery group headings must use the centered accent treatment from the reference layout.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__section\s*\{[^}]*display:\s*grid\s*;[^}]*grid-template-columns:\s*repeat\(3,\s*minmax\(0,\s*1fr\)\)\s*;[^}]*gap:\s*1\.25rem\s*;' 'Gallery must use a three-column desktop card grid.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__item\s*\{[^}]*display:\s*flex\s*;[^}]*flex-direction:\s*column\s*;[^}]*border-radius:\s*0\.5rem\s*;[^}]*box-shadow:\s*0\s+2px\s+6px\s+rgba\(0,\s*0,\s*0,\s*0\.1\)\s*;' 'Gallery items must use the reference-inspired card treatment.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__media\s*\{[^}]*overflow-x:\s*auto\s*;[^}]*scroll-snap-type:\s*x\s+mandatory\s*;' 'Gallery media must remain usable when a card contains multiple images.'
    Assert-Match $academicStyles '(?ms)\.academic-gallery__media\s+img\s*\{[^}]*height:\s*12\.5rem\s*;[^}]*object-fit:\s*cover\s*;' 'Gallery card images must use the reference layout fixed-height crop.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__body\s*\{[^}]*display:\s*flex\s*;[^}]*flex-direction:\s*column\s*;[^}]*flex:\s*1\s*;' 'Gallery card bodies must stretch so metadata can align at the bottom.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__meta\s*\{[^}]*margin-top:\s*auto\s*;' 'Gallery metadata must sit at the bottom of each card.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__section\.academic-gallery__section--activities\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s*;' 'Academic activity cards must occupy the full Gallery content width.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__section--activities \.academic-gallery__item\s*\{[^}]*display:\s*grid\s*;[^}]*grid-template-columns:\s*minmax\(18rem,\s*2fr\)\s+minmax\(0,\s*3fr\)\s*;[^}]*align-items:\s*stretch\s*;' 'Desktop academic activity cards must use a wide media-and-text layout to avoid excessive height.'
    Assert-Match $academicStyles '(?ms)^\.academic-gallery__section--activities \.academic-gallery__media\s*\{[^}]*height:\s*100%\s*;[^}]*min-height:\s*18rem\s*;' 'Wide academic activity cards must give their media a stable desktop height.'
    if ($academicStyles -match '(?m)^\.academic-gallery__item\s*\+\s*\.academic-gallery__item\s*\{') {
        throw 'Gallery cards must not retain list-style separator rules.'
    }
    Assert-Match $academicStyles '(?ms)@media\s*\(max-width:\s*1024px\)\s*\{.*?\.academic-gallery__section\s*\{[^}]*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)\s*;' 'Gallery must switch to two columns on tablet-sized screens.'
    Assert-Match $academicStyles '(?ms)@media\s*\(max-width:\s*768px\)\s*\{.*?\.academic-gallery__section\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s*;' 'Gallery must switch to one column on mobile screens.'
    Assert-Match $academicStyles '(?ms)@media\s*\(max-width:\s*768px\)\s*\{.*?\.academic-gallery__section--activities \.academic-gallery__item\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s*;' 'Academic activity cards must stack media above text on mobile screens.'
    $sidebarInclude = Read-Utf8File '_includes/sidebar.html'
    Assert-Match $sidebarInclude '(?ms)\{%\s*assign\s+show_author_profile\s*=\s*false\s*%\}.*?\{%\s*if\s+page\.url\s*==\s*"/"\s*%\}.*?\{%\s*if\s+page\.author_profile\s+or\s+layout\.author_profile\s*%\}.*?\{%\s*assign\s+show_author_profile\s*=\s*true\s*%\}.*?\{%\s*endif\s*%\}.*?\{%\s*endif\s*%\}' 'The author profile must be enabled only when the rendered page is Home.'
    Assert-Match $sidebarInclude '(?ms)\{%\s*if\s+show_author_profile\s+or\s+page\.sidebar\s*%\}.*?\{%\s*if\s+show_author_profile\s*%\}\s*\{%\s*include\s+author-profile\.html\s*%\}\s*\{%\s*endif\s*%\}' 'Subpages must omit the author profile while retaining support for explicit custom sidebars.'
    if ($sidebarInclude -match '\{%\s*if\s+page\.author_profile\s+or\s+layout\.author_profile\s+or\s+page\.sidebar\s*%\}') {
        throw 'The legacy sidebar condition would still render the author profile on subpages.'
    }
    Assert-Match $academicStyles '(?ms)^\s*#main\s*>\s*\.page:first-child,\s*\r?\n\s*#main\s*>\s*\.archive:first-child\s*\{[^}]*width:\s*100%\s*;[^}]*float:\s*none\s*;[^}]*max-width:\s*62\.5rem\s*;[^}]*margin-left:\s*auto\s*;[^}]*margin-right:\s*auto\s*;[^}]*padding-left:\s*0\s*;[^}]*padding-right:\s*0\s*;' 'Desktop subpages without a sidebar must use a centered content column instead of leaving an empty author column.'
    $authorProfile = Read-Utf8File '_includes/author-profile.html'
    Assert-Match $authorProfile '(?ms)<li class="author__desktop author__employer">\s*<i class="[^"]*\bicon-pad-right\b[^"]*"[^>]*></i>\s*<span class="author__employer-text">\{\{\s*author\.employer\s*\}\}</span>\s*</li>' 'The author employer must separate its icon and text so wrapped lines can align with the text column.'
    Assert-Match $academicStyles '(?ms)\.sidebar \.author__employer\s*\{[^}]*display:\s*grid\s*;[^}]*grid-template-columns:\s*max-content\s+minmax\(0,\s*1fr\)\s*;[^}]*align-items:\s*start\s*;' 'The author employer must use separate icon and text columns for aligned wrapped lines.'
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
