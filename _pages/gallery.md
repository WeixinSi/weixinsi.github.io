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
