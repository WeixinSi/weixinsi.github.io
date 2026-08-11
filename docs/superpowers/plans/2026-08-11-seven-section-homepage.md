# Seven-Section Academic Homepage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish Weixin Si's complete reviewed English academic profile through Home, Team, Research, Publications, Talks, Gallery, and More pages, then deploy the verified site to GitHub Pages.

**Architecture:** Keep Academic Pages as the rendering framework, replace its demonstration navigation and placeholder pages with seven focused pages, and split the reviewed draft by semantic section. Add a non-output `gallery` collection whose records are grouped on one Gallery page, plus small reusable Liquid includes and narrow Sass styles. A PowerShell source-contract test guards navigation, page presence, publication completeness, contact links, and prohibited ranking labels before the remote Jekyll build runs.

**Tech Stack:** Jekyll, Academic Pages, Markdown/Kramdown, Liquid, YAML, Sass, vanilla JavaScript, PowerShell, GitHub Actions, GitHub Pages.

## Global Constraints

- All public-facing copy is English-only.
- The reviewed `weixin-si-homepage-draft.md` is the primary copy source; `weixin-si-cv.tex` is authoritative when facts conflict.
- The complete 51 Journal Articles and 16 Conference Papers must be published.
- CCF, JCR, CAS tiers, and venue-family prestige annotations must not appear in publication entries.
- Editorial facts such as Oral and Best Paper Award Finalist may remain.
- GitHub must not appear in the homepage header, Contact section, author sidebar, or footer social links.
- The visible `Website` link must target `https://csce.suat-sz.edu.cn/info/1011/1311.htm`.
- Team members, talks, June 20 event metadata, and photographs must not be inferred or invented.
- Existing untracked `weixin-si-cv.pdf`, `weixin-si-cv.tex`, and `weixin-si-homepage-draft.md` must not be staged.
- Generated `_site` output must not be edited or committed.

## File Structure

- Modify `_config.yml`: public author metadata and the non-output `gallery` collection.
- Modify `_data/navigation.yml`: exact seven-item top navigation.
- Modify `_pages/about.md`: concise Home overview, biography, research summary, and News.
- Create `_pages/team.md`: verified-roster empty state and future card interface.
- Create `_pages/research.md`: research statement, four topic blocks, and all 14 funded projects.
- Delete `_pages/publications.html`; create `_pages/publications.md`: all 51 journal and 16 conference publications, filters, and year groups.
- Delete `_pages/talks.html`; create `_pages/talks.md`: Seminars and Invited Talks interface with a factual empty state.
- Create `_pages/gallery.md`: grouped Gallery landing page.
- Create `_pages/more.md`: Awards, Teaching, Services, Patents, Appointments, Education, and Contact.
- Modify `_includes/gallery`: accept an explicit image array while preserving current `page.gallery` behavior.
- Create `_includes/gallery-section.html`: render one Gallery category newest first.
- Create `_sass/layout/_academic-profile.scss`: restrained page, filter, topic, and Gallery styling.
- Modify `assets/css/main.scss`: import the new stylesheet.
- Create `_gallery/.gitkeep`: preserve the collection directory without publishing fabricated content.
- Create `scripts/validate-homepage.ps1`: source contract checks.

---

### Task 1: Add a Failing Homepage Source Contract

**Files:**
- Create: `scripts/validate-homepage.ps1`

**Interfaces:**
- Consumes: repository source files under `_config.yml`, `_data`, `_pages`, and `_includes`.
- Produces: exit code `0` and `Homepage source validation passed.` when all seven-page content contracts hold; throws with a specific message otherwise.

- [ ] **Step 1: Write the source-contract test**

```powershell
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
```

- [ ] **Step 2: Run the test and verify the pre-implementation failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-homepage.ps1
```

Expected: non-zero exit with `Navigation mismatch` because the template navigation is still active.

- [ ] **Step 3: Commit the failing contract**

```bash
git add -- scripts/validate-homepage.ps1
git commit -m "test: add academic homepage content contract"
```

### Task 2: Establish Navigation, Author Metadata, Home, Team, and Talks

**Files:**
- Modify: `_config.yml`
- Modify: `_data/navigation.yml`
- Modify: `_pages/about.md`
- Create: `_pages/team.md`
- Delete: `_pages/talks.html`
- Create: `_pages/talks.md`

**Interfaces:**
- Consumes: biography, Research Interest, News, and primary links from `weixin-si-homepage-draft.md`.
- Produces: canonical `/`, `/team/`, and `/talks/` pages plus the exact seven-link site navigation used by all later tasks.

- [ ] **Step 1: Update author metadata and collection configuration**

Set these exact `_config.yml` values while leaving `url`, `baseurl`, and `repository` unchanged:

```yaml
title                    : "Weixin Si"
name                     : &name "Weixin Si"
description              : &description "Academic homepage of Weixin Si"

author:
  avatar           : "wxsi.jpg"
  name             : "Weixin Si"
  bio              : "Associate Professor at Shenzhen University of Advanced Technology"
  location         : "Shenzhen, China"
  employer         : "Shenzhen University of Advanced Technology"
  uri              : "https://csce.suat-sz.edu.cn/info/1011/1311.htm"
  email            : "siweixin@suat-sz.edu.cn"
  googlescholar    : "https://scholar.google.com/citations?user=E4efwTgAAAAJ"
  github           :
```

Add the collection alongside the existing collections:

```yaml
  gallery:
    output: false
```

- [ ] **Step 2: Replace the active navigation**

```yaml
main:
  - title: "Home"
    url: /
  - title: "Team"
    url: /team/
  - title: "Research"
    url: /research/
  - title: "Publications"
    url: /publications/
  - title: "Talks"
    url: /talks/
  - title: "Gallery"
    url: /gallery/
  - title: "More"
    url: /more/
```

- [ ] **Step 3: Replace the Home placeholder with reviewed content**

Use this front matter and heading block:

```markdown
---
permalink: /
title: "Weixin Si, Ph.D."
author_profile: true
redirect_from:
  - /about/
  - /about.html
---

**Associate Professor (Teaching & Research) · Specially Appointed Full Professor**<br>
Faculty of Computer Science and Artificial Intelligence<br>
Shenzhen University of Advanced Technology

**Associate Director**<br>
Center for Evidence-Based Medicine and Artificial Intelligence

[Email](mailto:siweixin@suat-sz.edu.cn) ·
[Google Scholar](https://scholar.google.com/citations?user=E4efwTgAAAAJ) ·
[Website](https://csce.suat-sz.edu.cn/info/1011/1311.htm) ·
[Curriculum Vitae](/files/weixin-si-cv.pdf)
```

Immediately after it, copy exactly the continuous biography paragraph from the
reviewed draft between the first two horizontal rules. Then copy the complete
`## Research Interest` and `## News` sections, stopping before `## Awards`.
Keep the biography without a heading and remove the horizontal-rule separators.

- [ ] **Step 4: Create factual Team and Talks pages**

`_pages/team.md`:

```markdown
---
title: "Team"
permalink: /team/
author_profile: true
---

## Team

Team information will be updated as confirmed profiles become available.
```

Replace `_pages/talks.html` with `_pages/talks.md`:

```markdown
---
title: "Talks"
permalink: /talks/
author_profile: true
---

## Seminars

Seminar information will be added as confirmed records become available.

## Invited Talks

Invited talk information will be added as confirmed records become available.
```

- [ ] **Step 5: Run the contract and inspect the expected next failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-homepage.ps1
```

Expected: non-zero exit with `Missing required file: _pages/research.md`.

- [ ] **Step 6: Commit the site shell**

```bash
git add -- _config.yml _data/navigation.yml _pages/about.md _pages/team.md _pages/talks.md
git rm -- _pages/talks.html
git commit -m "feat: establish seven-section academic site"
```

### Task 3: Publish Research and More Content Without Omissions

**Files:**
- Create: `_pages/research.md`
- Create: `_pages/more.md`

**Interfaces:**
- Consumes: reviewed draft sections Research Interest, Funded Research Projects, Awards, Teaching, Recent Services, Patents, Professional Appointments, Education, and Contact.
- Produces: complete `/research/` and `/more/` pages; later validation depends on their headings and GitHub-free Contact content.

- [ ] **Step 1: Create the Research page**

Start `_pages/research.md` with:

```markdown
---
title: "Research"
permalink: /research/
author_profile: true
---

## Research Topics

Prof. Si's research is at the intersection of medical image analysis,
machine learning, biomechanical simulation, and computer-assisted
intervention. The overarching goal is to develop next-generation
intelligent systems that support the delivery of higher-quality medical
diagnosis, intervention, training, and education.

Previous representative works include fast interactive multi-physics
simulation for surgery, patient-specific digital-twin modeling and
augmented-reality navigation, data-efficient learning from multimodal
clinical data, and surgical video analysis for workflow understanding and
decision support.

<div class="research-topics">
  <article><h3>Intelligent Computer-Assisted Surgery</h3><p>Intelligent perception, planning, navigation, and decision support for safer and more precise surgical intervention.</p></article>
  <article><h3>Patient-Specific Medical Digital Twins</h3><p>Patient-specific modeling and simulation for treatment planning, rehearsal, and intraoperative guidance.</p></article>
  <article><h3>Multimodal Clinical Data Intelligence</h3><p>Data-efficient learning from medical images, physiological signals, electronic medical records, and surgical videos.</p></article>
  <article><h3>Interactive Medical Simulation and Extended Reality</h3><p>Interactive simulation, visualization, augmented reality, and extended reality for clinical training and education.</p></article>
</div>

## Funded Research Projects
```

Append all 14 numbered entries from the reviewed draft's `## Funded Research
Projects` section, preserving dates, project identifiers, amounts, roles, and
status exactly.

- [ ] **Step 2: Create the More page**

Use this front matter:

```markdown
---
title: "More"
permalink: /more/
author_profile: true
---
```

Append, in order and without omission, these exact reviewed draft ranges:

1. `## Awards` through the eighth award;
2. the complete `## Teaching` section;
3. `## Recent Services`, renamed `## Professional Services` while retaining
   Conference Services, Journal Services, and Professional Activities;
4. the complete 14-entry `## Patents` section;
5. `## Professional Appointments`;
6. `## Education`;
7. `## Contact`.

In Contact, replace the GitHub block with:

```markdown
Website:<br>
[csce.suat-sz.edu.cn/info/1011/1311.htm](https://csce.suat-sz.edu.cn/info/1011/1311.htm)
```

- [ ] **Step 3: Run the contract and inspect the expected publication failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-homepage.ps1
```

Expected: non-zero exit with `Missing required file: _pages/publications.md`.

- [ ] **Step 4: Commit Research and More**

```bash
git add -- _pages/research.md _pages/more.md
git commit -m "feat: publish research and professional record"
```

### Task 4: Publish the Complete Clean Publication Record

**Files:**
- Delete: `_pages/publications.html`
- Create: `_pages/publications.md`

**Interfaces:**
- Consumes: all entries between `### Journal Articles` and `## Funded Research Projects` in the reviewed draft.
- Produces: `/publications/` with exactly 51 journal articles, 16 conference papers, type filters, year headings, and no ranking annotations.

- [ ] **Step 1: Create the page shell and filter controls**

```markdown
---
title: "Publications"
permalink: /publications/
author_profile: true
---

<p><sup>#</sup> Co-first author · <sup>†</sup> Equal contribution · <sup>*</sup> Corresponding or co-corresponding author</p>

<div class="publication-filter" role="group" aria-label="Filter publications">
  <button type="button" class="is-active" data-publication-filter="all">All</button>
  <button type="button" data-publication-filter="journal">Journal Articles</button>
  <button type="button" data-publication-filter="conference">Conference Papers</button>
</div>

<section class="publication-group" data-publication-type="journal" markdown="1">

## Journal Articles
```

- [ ] **Step 2: Add all journal articles by year**

Copy all 51 journal entries from the reviewed draft. Add a fourth-level year
heading before the first entry of each year in this exact order:

```text
2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2014, 2012, 2011
```

Remove only bold parenthetical ranking notes matching CCF, JCR, CAS Tier, or
venue-family prestige wording. Preserve author order, symbols, titles, venues,
years, volume, issue, and page metadata.

- [ ] **Step 3: Add all conference papers by year**

After the journal entries, add:

```markdown
</section>

<section class="publication-group" data-publication-type="conference" markdown="1">

## Conference Papers
```

Copy all 16 conference entries and add fourth-level headings in this exact
order:

```text
2026, 2025, 2024, 2019
```

Remove CCF ranking text. Retain `ORAL` and `Best Paper Award Finalist` as factual
presentation or award information, normalizing combined annotations to forms
such as `**(Oral)**` and `**(Oral; Best Paper Award Finalist)**`. Close the
section and retain the Google Scholar link:

```markdown
</section>

[View the complete publication record on Google Scholar →](https://scholar.google.com/citations?user=E4efwTgAAAAJ)
```

- [ ] **Step 4: Add accessible client-side filter behavior**

```html
<script>
document.addEventListener('DOMContentLoaded', function () {
  var buttons = document.querySelectorAll('[data-publication-filter]');
  var groups = document.querySelectorAll('[data-publication-type]');
  buttons.forEach(function (button) {
    button.addEventListener('click', function () {
      var filter = button.getAttribute('data-publication-filter');
      buttons.forEach(function (item) {
        item.classList.toggle('is-active', item === button);
      });
      groups.forEach(function (group) {
        group.hidden = filter !== 'all' && group.getAttribute('data-publication-type') !== filter;
      });
    });
  });
});
</script>
```

- [ ] **Step 5: Run the contract and verify exact publication counts**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-homepage.ps1
```

Expected: non-zero exit with `Missing required file: _pages/gallery.md`; it must
not report a journal count, conference count, ranking label, or GitHub error.

- [ ] **Step 6: Commit Publications**

```bash
git add -- _pages/publications.md
git rm -- _pages/publications.html
git commit -m "feat: publish complete publication record"
```

### Task 5: Add the Grouped Gallery and Restrained Styling

**Files:**
- Create: `_pages/gallery.md`
- Create: `_includes/gallery-section.html`
- Modify: `_includes/gallery`
- Create: `_sass/layout/_academic-profile.scss`
- Modify: `assets/css/main.scss`
- Create: `_gallery/.gitkeep`

**Interfaces:**
- Consumes: `site.gallery` records with `category`, `date`, `title`, `description`, `source_url`, and `images` front-matter keys.
- Produces: one `/gallery/` page grouped into `visitors`, `publicity`, and `activities`; the existing `{% include gallery %}` interface remains compatible and gains `{% include gallery images=item.images %}`.

- [ ] **Step 1: Extend the existing Gallery include compatibly**

At the top of `_includes/gallery`, use this precedence:

```liquid
{% include base_path %}

{% if include.images %}
  {% assign gallery = include.images %}
{% elsif include.id %}
  {% assign gallery = page.[include.id] %}
{% else %}
  {% assign gallery = page.gallery %}
{% endif %}
```

Leave the existing size-based layout, URL resolution, alt text, and caption
logic unchanged.

- [ ] **Step 2: Create the category renderer**

```liquid
{% assign gallery_items = site.gallery | where: "category", include.category | sort: "date" | reverse %}
{% if gallery_items.size > 0 %}
  <section class="academic-gallery__section">
    {% for item in gallery_items %}
      <article class="academic-gallery__item">
        {% if item.images and item.images.size > 0 %}
          {% include gallery images=item.images %}
        {% endif %}
        <h3>{{ item.title }}</h3>
        {% if item.description %}{{ item.description | markdownify }}{% endif %}
        <p class="academic-gallery__meta">
          {% if item.date %}{{ item.date | date: "%B %Y" }}{% endif %}
          {% if item.source_url %} · <a href="{{ item.source_url }}">Source</a>{% endif %}
        </p>
      </article>
    {% endfor %}
  </section>
{% endif %}
```

- [ ] **Step 3: Create the grouped Gallery page**

```markdown
---
title: "Gallery"
permalink: /gallery/
author_profile: true
---

{% assign gallery_count = site.gallery | size %}

## Distinguished Visitors

{% include gallery-section.html category="visitors" %}

## Publicity

{% include gallery-section.html category="publicity" %}

## Academic Events & Activities

{% include gallery-section.html category="activities" %}

{% if gallery_count == 0 %}
<p class="gallery-empty">Selected photographs from academic events and activities will be added here.</p>
{% endif %}
```

- [ ] **Step 4: Add narrow academic styling**

Create `_sass/layout/_academic-profile.scss`:

```scss
.research-topics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
  margin: 1.25rem 0 2rem;

  article {
    border-top: 2px solid mix(#000, $background-color, 18%);
    padding: 1rem 0.25rem 0;
  }

  h3 { margin-top: 0; }
}

.publication-filter {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin: 1rem 0 2rem;

  button {
    background: transparent;
    border: 1px solid mix(#000, $background-color, 22%);
    border-radius: 999px;
    color: $text-color;
    cursor: pointer;
    padding: 0.4rem 0.85rem;
  }

  button:hover,
  button:focus-visible,
  button.is-active {
    border-color: $link-color;
    color: $link-color;
  }
}

.publication-group[hidden] { display: none; }

.academic-gallery__item {
  border-top: 1px solid mix(#000, $background-color, 14%);
  margin: 1.25rem 0 2.25rem;
  padding-top: 1.25rem;
}

.academic-gallery__meta,
.gallery-empty {
  color: mix($text-color, $background-color, 70%);
  font-size: 0.9em;
}

@media (max-width: 600px) {
  .research-topics { grid-template-columns: 1fr; }
}
```

Import it as the final item in `assets/css/main.scss`:

```scss
    "layout/json_cv",
    "layout/academic-profile"
;
```

- [ ] **Step 5: Preserve the empty collection and run the contract**

Create the empty `_gallery/.gitkeep`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-homepage.ps1
```

Expected: `Homepage source validation passed.`

- [ ] **Step 6: Commit Gallery and styling**

```bash
git add -- _pages/gallery.md _includes/gallery _includes/gallery-section.html _sass/layout/_academic-profile.scss assets/css/main.scss _gallery/.gitkeep
git commit -m "feat: add grouped academic gallery"
```

### Task 6: Verify, Rebase, Deploy, and Inspect GitHub Pages

**Files:**
- Verify all files staged by Tasks 1–5.
- Do not add the three untracked CV/draft source files.

**Interfaces:**
- Consumes: completed seven-page site and GitHub Actions workflow.
- Produces: updated `origin/master` and a successful public GitHub Pages preview.

- [ ] **Step 1: Run local source and whitespace checks**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-homepage.ps1
git diff --check
git status --short --branch
```

Expected: source validation passes, `git diff --check` is silent, the branch is
ahead only by reviewed commits, and the three local source files remain
untracked.

- [ ] **Step 2: Attempt the narrow local Jekyll build**

```powershell
bundle exec jekyll build --strict_front_matter
```

Expected on a Ruby-enabled environment: exit `0`. On the current Windows host,
Ruby and Bundler are absent; record that limitation and use the repository's
GitHub Actions Jekyll build as the authoritative render check.

- [ ] **Step 3: Review every commit and the complete diff**

```bash
git log --oneline origin/master..HEAD
git diff --stat origin/master...HEAD
git diff --check origin/master...HEAD
```

Expected: only design, plan, validation, source pages, navigation, metadata,
Gallery support, and styling changes are present.

- [ ] **Step 4: Rebase and push with Git Bash**

```bash
git pull --rebase origin master
git push origin master
```

Expected: push updates `WeixinSi/weixinsi.github.io` without staging untracked
local files.

- [ ] **Step 5: Inspect the GitHub Pages workflow and public routes**

Use GitHub's workflow/API view to confirm the pushed SHA receives a successful
Jekyll build. Then verify HTTP `200` and visible expected headings at:

```text
https://weixinsi.github.io/
https://weixinsi.github.io/team/
https://weixinsi.github.io/research/
https://weixinsi.github.io/publications/
https://weixinsi.github.io/talks/
https://weixinsi.github.io/gallery/
https://weixinsi.github.io/more/
```

Check that the public sidebar shows Website, Email, and Google Scholar without
GitHub; Publications contains 51 journal and 16 conference entries without
ranking labels; and Gallery shows the three headings plus the empty-state copy.
