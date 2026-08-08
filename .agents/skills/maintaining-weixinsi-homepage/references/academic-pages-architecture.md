# Academic Pages 架构与编辑参考

本参考适用于 `WeixinSi/weixinsi.github.io` 当前使用的 [Academic Pages](https://github.com/academicpages/academicpages.github.io) 模板。它用于定位修改入口，不替代对本地文件的检查。模板会演进；本地仓库中的实际配置、Liquid 模板和工作流始终优先。

## 目录

- [生成链路](#生成链路)
- [目录和文件职责](#目录和文件职责)
- [内容模型与 front matter](#内容模型与-front-matter)
- [修改目标到文件的映射](#修改目标到文件的映射)
- [安全编辑边界](#安全编辑边界)
- [验证与预览](#验证与预览)
- [部署与 Actions](#部署与-actions)
- [常见故障定位](#常见故障定位)

## 生成链路

```text
_config.yml + _data/*.yml
        +
_pages/、_posts/ 和各 collection 的 Markdown/HTML
        ↓ Jekyll 解析 YAML front matter 与 Liquid
_layouts/ 页面骨架 + _includes/ 可复用片段
        +
assets/css/main.scss → _sass/；assets/js/main.min.js；images/；files/
        ↓
静态站点输出到 _site/
        ↓ GitHub Pages
https://weixinsi.github.io/
```

只编辑源文件，不编辑 `_site/`。`_site/` 是可重新生成的构建产物。

## 目录和文件职责

### 全站配置与数据

| 路径 | 职责 | 常见字段或用途 |
|---|---|---|
| `_config.yml` | 全站身份、网址、作者侧栏、collections、默认布局、插件、主题 | `title`、`name`、`description`、`url`、`baseurl`、`repository`、`author`、`publication_category`、`collections`、`defaults`、`site_theme` |
| `_data/navigation.yml` | 顶部导航的文字、目标与顺序 | `main[].title`、`main[].url` |
| `_data/authors.yml` | 多作者资料；仅在页面显式指定作者时需要 | 作者键及其资料字段 |
| `_data/ui-text.yml` | 主题界面文案与多语言标签 | 按 `site.locale` 选择 |
| `_data/cv.json` | JSON 版 CV 的结构化数据源 | `basics`、`work`、`education`、`skills`、`publications` 等 |

个人用户主页仓库应保持：

```yaml
url: "https://weixinsi.github.io"
baseurl: ""
repository: "WeixinSi/weixinsi.github.io"
```

`_config.yml` 改动后，Jekyll 本地服务通常需要重启。

### 页面与内容集合

| 路径 | 内容 |
|---|---|
| `_pages/about.md` | 首页正文；`permalink: /` 决定根网址 |
| `_pages/publications.html` | 论文列表页；遍历 `site.publications` 并按类别分组 |
| `_pages/talks.html`、`teaching.html`、`portfolio.html` | 对应 collection 的汇总页 |
| `_pages/cv.md` | 手写 Markdown CV，并可汇总论文、报告和教学 |
| `_pages/cv-json.md` | 使用 `_data/cv.json` 与 `_includes/cv-template.html` 渲染的 CV |
| `_pages/year-archive.html` | 博客按年份归档 |
| `_publications/` | 每篇论文一个 Markdown 文件 |
| `_talks/` | 每场报告一个 Markdown 文件 |
| `_teaching/` | 每段教学经历一个 Markdown 文件 |
| `_portfolio/` | 每个项目一个 Markdown 或 HTML 文件 |
| `_posts/` | 博客文章，文件名使用 `YYYY-MM-DD-title.md` |
| `_drafts/` | 默认不发布的草稿 |

`_config.yml` 中的 `collections` 控制集合是否输出以及默认 permalink；`defaults` 为不同内容类型提供默认 `layout`、`author_profile`、`share` 等值。先检查默认值，再决定是否在单个文件中重复设置。

### 渲染层

| 路径 | 职责 |
|---|---|
| `_layouts/compress.html` | 最外层 HTML 压缩包装 |
| `_layouts/default.html` | 全站 HTML 骨架，装配 head、masthead、footer 和 scripts |
| `_layouts/single.html` | 常规单页、文章、论文详情页 |
| `_layouts/archive.html` | publications、talks、teaching、portfolio、CV 等列表页 |
| `_layouts/talk.html` | talk 详情页 |
| `_includes/author-profile.html` | 左侧头像、姓名、简介和社交链接 |
| `_includes/masthead.html` | 顶部导航容器 |
| `_includes/archive-single.html` | 通用列表卡片，处理摘要、citation、paper/slides/bibtex 链接 |
| `_includes/archive-single-talk.html` | talk 列表条目 |
| `_includes/cv-template.html` | JSON CV 的渲染模板 |
| `_includes/head/custom.html` | 追加自定义 head 内容的低冲突入口 |
| `_includes/footer/custom.html` | 追加自定义页脚内容的低冲突入口 |

页面外观异常时，沿“内容 front matter → archive 页面 → include → layout”的顺序追踪，不要一开始就改底层 layout。

### 样式、脚本与静态资源

| 路径 | 职责 |
|---|---|
| `assets/css/main.scss` | Sass 总入口；前两行 front matter 必须保留 |
| `_sass/_themes.scss` | 主题颜色公共定义 |
| `_sass/theme/` | `default`、`air`、`sunrise`、`mint`、`dirt`、`contrast` 的明暗主题 |
| `_sass/layout/` | 页面布局、导航、侧栏、归档、CV 等组件样式 |
| `_sass/include/` | mixin 与工具类 |
| `assets/js/_main.js`、`theme.js` | JavaScript 源文件 |
| `assets/js/main.min.js` | 页面实际加载的合并压缩脚本；修改源脚本后用 `npm run build:js` 重新生成 |
| `images/` | 头像、favicon、正文图片；`author.avatar` 通常写相对此目录的文件名 |
| `files/` | PDF、BibTeX、幻灯片、压缩包等可下载资源 |

仅切换现成配色时修改 `_config.yml` 的 `site_theme`。需要局部视觉调整时，先定位对应 `_sass/layout/` 文件；需要全站结构变化时才修改 `_layouts/` 或核心 `_includes/`。

### 工具与构建文件

| 路径 | 职责 |
|---|---|
| `Gemfile` | Jekyll、GitHub Pages 与插件依赖 |
| `Dockerfile`、`docker-compose.yaml`、`_config_docker.yml` | Docker 本地预览 |
| `.devcontainer/` | VS Code Dev Container 环境 |
| `markdown_generator/` | 从 CSV/TSV/BibTeX/ORCID 辅助生成 publications 或 talks Markdown |
| `scripts/cv_markdown_to_json.py` | 将 CV 内容辅助转换为 JSON 数据 |
| `talkmap.py`、`talkmap/` | 报告地点地图生成和静态资源 |
| `.github/workflows/` | Jekyll 构建检查及 talk map 等自动化 |

生成器会批量写内容文件。运行前先读脚本和输入格式，确认输出目标；不得覆盖已经人工定制的条目。

## 内容模型与 front matter

所有被 Jekyll 处理的 Markdown/HTML 内容必须以成对的 `---` 包围 YAML front matter。YAML 使用空格缩进，不使用 Tab；含冒号、引号、HTML 或公式的长值优先加引号。

### 首页与普通页面

```yaml
---
permalink: /
title: "About Me"
author_profile: true
redirect_from:
  - /about/
  - /about.html
---
```

- `permalink` 决定公开 URL；改动前检查导航和外部链接。
- `layout` 未写时通常由 `_config.yml` 的 `defaults` 提供。
- `author_profile` 控制是否显示作者侧栏。
- 顶部导航与页面是否存在是两件事：从 `navigation.yml` 删除入口不会删除页面。

### 论文

```yaml
---
title: "Paper title"
collection: publications
category: conferences
permalink: /publication/2026-paper-slug
excerpt: "One-sentence summary."
date: 2026-01-01
venue: "Conference or Journal"
paperurl: "/files/paper.pdf"
slidesurl: "/files/slides.pdf"
bibtexurl: "/files/paper.bib"
citation: "Author. (2026). Paper title. Venue."
---
```

- `category` 必须对应 `_config.yml` 的 `publication_category` 键，如 `books`、`manuscripts`、`conferences`，否则分类列表可能不显示。
- `paperurl`、`slidesurl`、`bibtexurl` 可按实际资源省略；`archive-single.html` 会根据已有字段组合链接。
- `citation` 允许有限 HTML；修改后必须构建检查。
- 文件名建议以 `YYYY-MM-DD-` 开头，`date` 使用 ISO `YYYY-MM-DD`。
- 正文显示在论文详情页，`excerpt` 显示在汇总页。

### Talks 与 Teaching

```yaml
---
title: "Talk or teaching title"
collection: talks
type: "Conference talk"
permalink: /talks/2026-01-01-topic
venue: "Organization or course"
date: 2026-01-01
location: "City, Country"
---
```

Teaching 条目将 `collection` 和 permalink 前缀改为 `teaching`。正文可使用 Markdown。Talk 列表由 `archive-single-talk.html` 渲染，不能假设它与普通 `archive-single.html` 支持完全相同的字段。

### Portfolio 与博客

Portfolio 常用 `title`、`excerpt`、`collection: portfolio`，正文可为 Markdown 或 HTML。博客必须放在 `_posts/` 且文件名包含有效日期；分类与标签分别供 category/tag archive 使用。

### 两种 CV

- 需要自由排版时编辑 `_pages/cv.md`。
- 需要结构化 CV 时编辑 `_data/cv.json`，页面入口为 `_pages/cv-json.md`。
- `_data/navigation.yml` 中只启用一个 CV 导航项，避免两个入口同时出现。
- PDF 下载链接通常指向 `/files/cv.pdf`；只有文件真实存在时才展示链接。

## 修改目标到文件的映射

| 用户目标 | 首选文件 | 必要时继续检查 |
|---|---|---|
| 改姓名、站点标题、简介、联系方式、社交链接 | `_config.yml` | `_includes/author-profile.html` |
| 改首页介绍 | `_pages/about.md` | `_config.yml` 的 author 侧栏 |
| 改头像 | `images/<头像文件>` 与 `_config.yml: author.avatar` | 图片尺寸、大小写和扩展名 |
| 增删或排序顶部菜单 | `_data/navigation.yml` | 对应页面的 `permalink` |
| 添加论文 | `_publications/<date>-<slug>.md`、`files/` | `_config.yml: publication_category`、`_pages/publications.html` |
| 添加报告 | `_talks/<date>-<slug>.md` | `_pages/talks.html`、talk map |
| 添加教学或项目 | `_teaching/` 或 `_portfolio/` | 对应 archive 页面 |
| 修改 CV | `_pages/cv.md` 或 `_data/cv.json` | `_pages/cv-json.md`、`files/cv.pdf`、导航 |
| 切换内置主题 | `_config.yml: site_theme` | `_sass/theme/` |
| 调整局部样式 | `_sass/layout/` 或 `_sass/theme/` | `assets/css/main.scss` 导入顺序 |
| 改列表条目格式 | `_includes/archive-single*.html` | 调用它的 `_pages/*.html` |
| 改页面整体骨架 | `_layouts/` | `_includes/`、响应式 Sass |
| 加统计或 head 标签 | `_config.yml: analytics` 或 `_includes/head/custom.html` | `_includes/analytics*.html` |
| 加下载文件 | `files/` 与引用它的 front matter/正文 | URL、文件名大小写 |
| 修改脚本行为 | `assets/js/_main.js` 或 `theme.js` | `npm run build:js` 与 `main.min.js` |

## 安全编辑边界

1. 先修改内容或配置层；只有现有字段和模板无法实现需求时才深入 include/layout/Sass。
2. 不编造真实姓名之外的学历、单位、职位、论文、奖项、邮箱或社交账号。缺少事实时保留空值、占位标记或在唯一一次汇总确认中询问。
3. 删除模板示例前区分“隐藏导航”“删除页面”“删除 collection 条目”。它们影响不同范围。
4. 保留 front matter 两条边界线、YAML 缩进、Liquid 的 `{% ... %}`/`{{ ... }}` 和 Sass import 末尾分号。
5. 资源文件名和 URL 区分大小写。站内资源优先使用 `/images/...`、`/files/...`，并确认 `baseurl` 场景；当前用户主页的 `baseurl` 为空。
6. 不把密钥、访问令牌、私密邮箱或未公开材料写入仓库。GitHub Pages 仓库中的源文件和构建产物可能公开。
7. 不随意同步或整批覆盖上游模板。本仓库从模板独立定制后，直接合并上游可能产生冲突；按需审阅、挑选变更。
8. 不通过修改 workflow 来绕过构建错误；先修复源文件或依赖问题。

## 验证与预览

按改动风险选择最窄但充分的验证：

1. 始终运行 `git diff --check`，检查完整 diff 和未跟踪文件。
2. YAML/front matter 改动：使用已安装的 YAML 解析器验证；如调用 Python，先激活 conda `torch`。
3. Jekyll 内容或模板改动：若依赖已经安装，运行：

   ```bash
   bundle exec jekyll build --strict_front_matter
   ```

4. 本地预览：

   ```bash
   bundle exec jekyll serve -l -H localhost
   ```

   打开 `http://localhost:4000`。修改 `_config.yml` 后重启服务。
5. JavaScript 源文件改动：在依赖已存在时运行 `npm run build:js`，确认 `assets/js/main.min.js` 更新。
6. 检查主要页面 `/`、`/publications/`、`/talks/`、`/teaching/`、`/portfolio/`、`/cv/`，以及新 permalink 和资源链接。

不要为了验证而擅自安装 Ruby、Node 或 Python 依赖。缺少环境时，完成静态检查并明确报告未运行的构建。

## 部署与 Actions

- 推送到远端与部署是两个独立结果。仅在用户明确授权 push 时推送。
- GitHub Pages 的发布来源由仓库 `Settings → Pages` 决定；不要仅凭本地文件猜测当前设置。
- `.github/workflows/jekyll-build.yml` 执行 `bundle exec jekyll build --strict_front_matter`，属于构建检查。工作流触发分支必须与仓库实际默认/发布分支核对；本项目当前工作分支是 `master`。
- GitHub 自动生成的 `pages-build-deployment` 可能负责实际 Pages 发布；部署请求完成后检查仓库 `Actions` 和 Pages 设置中的状态与公开网址。
- `scrape_talks.yml` 可执行 notebook 并回写 talk map。改动 `_talks/` 前先判断是否会触发它及是否需要相应权限。

## 常见故障定位

| 症状 | 优先检查 |
|---|---|
| 首页 404 或不是 About | `_pages/about.md` 是否有 `permalink: /`，`_config.yml` 是否 include `_pages` |
| 顶部菜单存在但链接 404 | `navigation.yml` URL 与目标页面 permalink 是否一致 |
| 页面存在但菜单不显示 | `navigation.yml` 的 `main` 列表、YAML 缩进 |
| 头像不显示 | `author.avatar` 是否为 `images/` 下实际文件名，大小写是否一致 |
| 论文未出现在列表 | 文件位置、front matter、`category`、日期、`_pages/publications.html` 的过滤逻辑 |
| 下载链接失效 | `files/` 中是否存在同名文件，URL 大小写与 baseurl 是否正确 |
| 样式改动无效 | Sass 文件是否被 `main.scss` 导入、主题文件是否与 `site_theme` 匹配、缓存是否刷新 |
| 本地改配置后无变化 | 停止并重启 Jekyll server |
| Actions 构建失败 | workflow 日志中的首个错误、front matter、Liquid、Gem 依赖与触发分支 |
| 本地成功但线上未更新 | push 是否成功、Pages 发布来源、Actions 部署状态、缓存与目标 URL |

## 参考来源

- 上游仓库：`https://github.com/academicpages/academicpages.github.io`
- 上游说明：`README.md`
- 上游结构基准：`_config.yml`、`_data/navigation.yml`、各 collection 示例、`_layouts/`、`_includes/`、`.github/workflows/`
- 本参考最后核对日期：2026-08-09
