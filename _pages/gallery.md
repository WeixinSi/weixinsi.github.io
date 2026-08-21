---
title: "Gallery"
permalink: /gallery/
author_profile: true
hide_title: true
---

{% assign gallery_count = site.gallery | size %}

{% include gallery-section.html category="visitors" title="Distinguished Visitors" %}

{% include gallery-section.html category="publicity" title="Publicity" %}

{% include gallery-section.html category="activities" title="Academic Events & Activities" %}

{% if gallery_count == 0 %}
<p class="gallery-empty">Selected photographs from academic events and activities will be added here.</p>
{% endif %}
