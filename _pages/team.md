---
title: "Team"
permalink: /team/
author_profile: true
---

<p class="team-intro">Meet the current and incoming members of our team. Portraits and additional profile details will be updated as confirmed information becomes available.</p>

{% for group in site.data.team.current_members %}
<section class="team-section" aria-labelledby="{{ group.id }}">
  <h2 id="{{ group.id }}">{{ group.title }}</h2>
  <div class="team-grid">
    {% for member in group.members %}
    <article class="team-card">
      {% if member.profile %}<a class="team-card__portrait-link" href="{{ member.profile }}" aria-label="View {{ member.name }}'s profile">{% endif %}
      <img class="team-card__portrait" src="{{ member.image | relative_url }}" alt="{% if member.image == '/images/bio-photo.jpg' %}Temporary portrait for{% else %}Portrait of{% endif %} {{ member.name }}" loading="lazy">
      {% if member.profile %}</a>{% endif %}
      <div class="team-card__body">
        <h3>{% if member.profile %}<a href="{{ member.profile }}">{{ member.name }}</a>{% else %}{{ member.name }}{% endif %}</h3>
        {% if member.role %}
        <p class="team-card__role">{{ member.role }}</p>
        {% endif %}
        {% if member.background %}
        <p>{{ member.background }}</p>
        {% endif %}
        {% if member.focus %}
        <p class="team-card__focus">{{ member.focus }}</p>
        {% endif %}
      </div>
    </article>
    {% endfor %}
  </div>
</section>
{% endfor %}

{% if site.data.team.alumni and site.data.team.alumni.groups %}
<section class="team-alumni" aria-labelledby="alumni">
  <h2 id="alumni">{{ site.data.team.alumni.title }}</h2>
  {% for group in site.data.team.alumni.groups %}
  <div class="team-alumni__group" aria-labelledby="{{ group.id }}">
    <h3 id="{{ group.id }}">{{ group.title }}</h3>
    <ul class="team-alumni__list">
      {% for alumnus in group.members %}
      <li><strong>{{ alumnus.name }}</strong> ({{ alumnus.period }}), {{ alumnus.current }}</li>
      {% endfor %}
    </ul>
  </div>
  {% endfor %}
</section>
{% endif %}
