# Weixin Si Academic Homepage and Gallery Design

## Context

The repository is based on Academic Pages. The live homepage still contains the
template's short under-construction copy, while the reviewed English academic
profile is stored in `weixin-si-homepage-draft.md` and is not rendered by
Jekyll. The template navigation and example Portfolio entries also remain.

The website should now publish the complete reviewed profile through a
restrained, multi-page academic structure inspired by Qi Dou's faculty website:
Home, Team, Research, Publications, Talks, Gallery, and More. The information
architecture and writing logic may follow that reference, but all facts,
research topics, people, publications, and activities must remain specific to
Weixin Si and supported by the CV or reviewed draft.

## Goals

- Publish the complete English profile from the reviewed homepage draft.
- Establish the seven top-level sections Home, Team, Research, Publications,
  Talks, Gallery, and More.
- Distribute the reviewed material into focused pages without omitting CV
  content.
- Give Gallery clear internal categories for future event photography.
- Remove GitHub from public contact links and use the official institutional
  profile as the Website link.
- Remove CCF, JCR, CAS, and similar venue-ranking annotations from journal and
  conference publication entries.
- Preserve a quiet, polished visual tone consistent with established academic
  faculty homepages.
- Keep future additions simple: one Markdown file and a set of images per
  event.

## Information Architecture

The reference model was reviewed page by page rather than copied as a visual
skin. Its useful editorial patterns are: a compact biography and research
summary on [Home](https://www.cse.cuhk.edu.hk/~qdou/), role-based people groups
on [Team](https://www.cse.cuhk.edu.hk/~qdou/homepage/team/), introductory prose
followed by topic blocks on
[Research](https://www.cse.cuhk.edu.hk/~qdou/homepage/research/), filters and
year groups on
[Publications](https://www.cse.cuhk.edu.hk/~qdou/homepage/publication/),
Seminars and Invited Talks on
[Talks](https://www.cse.cuhk.edu.hk/~qdou/homepage/talks/), editorial photo
groups on
[Gallery](https://www.cse.cuhk.edu.hk/~qdou/homepage/lab_gallery/), and Awards,
Professional Services, and contact-oriented material on
[More](https://www.cse.cuhk.edu.hk/~qdou/homepage/more/).

### Navigation

The active top navigation follows this order:

1. Home
2. Team
3. Research
4. Publications
5. Talks
6. Gallery
7. More

The template's demonstration-only Portfolio, Blog Posts, CV, and Guide links
will not appear in the active navigation. Their underlying interfaces may stay
in the repository for later reuse.

### Home

`_pages/about.md` remains the canonical page at `/`. Like the reference home
page, it acts as a concise overview rather than a duplicate of every section.
It contains:

1. name, appointments, affiliation, and primary links;
2. one continuous biography paragraph without a Biography heading;
3. a concise Research Interest summary and numbered recent-focus line; and
4. selected News in reverse chronological order.

The existing portrait and author area are retained. All visible copy remains
English-only.

### Team

`/team/` follows the reference page's people-first structure: current members
first, followed by alumni or former members when those facts are available.
Each person card is limited to a portrait, name, role and period, education, and
co-supervision note when applicable.

Neither the CV nor the reviewed draft currently establishes a verified team
roster. The first release therefore provides the page and its maintainable card
structure without inferring team membership from co-authorship. It displays a
brief neutral update message until confirmed member data is supplied.

### Research

`/research/` begins with the reviewed interdisciplinary research statement,
then presents the four confirmed recent-focus areas as clear topic blocks:

1. Intelligent Computer-Assisted Surgery
2. Patient-Specific Medical Digital Twins
3. Multimodal Clinical Data Intelligence
4. Interactive Medical Simulation and Extended Reality

The complete Funded Research Projects list follows the topic overview so that
all project information from the reviewed draft remains available. Topic copy
will be concise and derived only from the reviewed biography, research section,
and project descriptions.

### Publications

`/publications/` contains the complete Journal Articles and Conference Papers
lists. It follows the reference page's scan-friendly logic with type filters
and reverse-chronological year groups, while retaining the source order within
each year. The initial filters are All, Journal Articles, and Conference
Papers; unsupported research-topic classifications will not be invented.

### Talks

`/talks/` reserves the reference structure of Seminars and Invited Talks. No
talks are listed in the reviewed draft or CV, so the initial page presents a
short update message instead of repurposing unrelated conference service or
publication entries. The data structure remains ready for title, venue, city,
and month/year fields when confirmed records are supplied.

### Gallery

`/gallery/` follows the reference Gallery's grouped editorial logic rather than
using a generic portfolio archive. Its internal sections are:

1. Distinguished Visitors
2. Publicity
3. Academic Events & Activities

The third label broadens the reference site's student-activity category to fit
a personal academic website and covers conferences, workshops, meetings,
demonstrations, and community activities. A future June 20 event belongs in
this section once its confirmed year, title, caption, and photographs are
available.

Each Gallery item consists of one or more photographs followed by a concise,
factual caption, normally ending with month and year. Multiple photographs for
one item use the repository's responsive `gallery` include and open at full
size. Images use a predictable path such as:

```text
images/gallery/YYYY-MM-DD-event-slug/
```

Gallery records use a dedicated Jekyll collection. One Markdown record stores
the confirmed category, date, title, caption, optional source link, and image
list for an activity. The `/gallery/` page groups those records by category and
sorts them newest first, producing the reference site's single-page grouped
presentation while keeping each future update isolated and easy to maintain.

No event name, date, or photograph will be invented for the initial release.
The page will display a restrained empty-state message until real material is
added.

### More

`/more/` gathers material that is important but secondary to the main research
narrative, following the reference page's Awards and Professional Services
logic. It contains the complete reviewed sections in this order:

1. Awards
2. Teaching
3. Professional Services
4. Patents
5. Professional Appointments
6. Education
7. Contact

## Contact Rules

- The visible label is `Website`.
- `Website` links to the official institutional profile:
  `https://csce.suat-sz.edu.cn/info/1011/1311.htm`.
- GitHub is removed from the homepage header, Contact section, author sidebar,
  and footer social links.
- Email, Google Scholar, institutional Website, and Curriculum Vitae remain
  available where supported by the reviewed content.

## Publication Formatting

Journal Articles and Conference Papers retain complete bibliographic content:
authors, contribution symbols, title, venue, and year. Ranking or indexing
annotations are removed, including labels such as:

- CCF-A / CCF-B
- JCR Q1 and similar quartiles
- CAS Tier 1 and similar CAS tiers
- Venue-family prestige notes used as ranking annotations

Editorial status or factual presentation information that is part of the
publication record, such as accepted, oral presentation, or award recognition,
may remain when present in the reviewed source. Award information also remains
in the dedicated Awards and News sections.

## Visual Direction

The implementation will use the existing Academic Pages typography and spacing
as the base. Styling changes, if needed, will be narrow and content-led:

- neutral colors and generous whitespace;
- a consistent seven-item navigation bar on desktop and a compact menu on
  smaller screens;
- compact academic metadata and consistent page headings;
- restrained topic and people cards without decorative gradients or excessive
  animation;
- responsive photo grids that preserve image aspect ratios;
- captions used only when they add factual context.

## Content and Data Safety

- The reviewed draft is the primary copy source for the seven public pages.
- The CV remains the authority when a factual conflict is discovered.
- The reference website informs hierarchy, brevity, and presentation only; its
  people, achievements, research topics, and descriptions are never copied as
  facts about Weixin Si.
- Existing untracked CV and draft files are not deleted or included in the
  website commit unless deliberately required as published assets.
- Template source files are edited; generated `_site` output is never edited.
- Sample Portfolio content must not appear as real academic or event content.

## Validation

Before deployment:

1. Run `git diff --check`.
2. Build Jekyll with strict front matter.
3. Inspect generated `/`, `/team/`, `/research/`, `/publications/`, `/talks/`,
   `/gallery/`, `/more/`, navigation, author profile, and footer.
4. Search rendered output for template sample content and prohibited
   publication-ranking labels.
5. Verify external Website and Google Scholar URLs in source.
6. Review the exact staged diff before committing.
7. Rebase on `origin/master`, push `master`, and inspect the GitHub Pages build
   and public preview.

## Out of Scope for This Release

- Adding fabricated or placeholder event photographs.
- Creating a specific June 20 event before its confirmed title, year, copy, and
  photographs are supplied.
- Inventing team members or talks from publication authorship or conference
  records.
- Redesigning the entire Academic Pages theme.
- Removing dormant collections or template interfaces that may be reused later.
- Publishing the local LaTeX CV source file.
