---
title: "Team"
permalink: /team/
author_profile: true
---

<p class="team-intro">Our team works at the intersection of medical artificial intelligence, computer-assisted surgery, medical digital twins, and immersive technologies. The profiles below are temporary placeholders for layout review and will be replaced with confirmed member information.</p>

{% for group in site.data.team.current_members %}
<section class="team-section" aria-labelledby="{{ group.id }}">
  <h2 id="{{ group.id }}">{{ group.title }}</h2>
  <div class="team-grid">
    {% for member in group.members %}
    <article class="team-card">
      {% if member.profile %}<a class="team-card__portrait-link" href="{{ member.profile }}" aria-label="View {{ member.name }}'s profile">{% endif %}
      <img class="team-card__portrait" src="{{ member.image | relative_url }}" alt="Temporary portrait for {{ member.name }}" loading="lazy">
      {% if member.profile %}</a>{% endif %}
      <div class="team-card__body">
        <h3>{% if member.profile %}<a href="{{ member.profile }}">{{ member.name }}</a>{% else %}{{ member.name }}{% endif %}</h3>
        <p class="team-card__role">{{ member.role }}</p>
        <p>{{ member.background }}</p>
        <p class="team-card__focus">{{ member.focus }}</p>
      </div>
    </article>
    {% endfor %}
  </div>
</section>
{% endfor %}

<section class="team-alumni" aria-labelledby="alumni">
  <h2 id="alumni">Alumni</h2>
  {% for group in site.data.team.alumni_groups %}
  <div class="team-alumni__group">
    <h3 id="{{ group.id }}">{{ group.title }}</h3>
    <ul class="team-alumni__list">
      {% for member in group.members %}
      <li>{{ member }}</li>
      {% endfor %}
    </ul>
  </div>
  {% endfor %}
</section>
