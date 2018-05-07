{% from 'php_fpm/map.jinja' import php_fpm with context %}

{% for pkg in php_fpm.packages %}
php_fpm_pkg_{{ pkg }}:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}

php_fpm_main_config:
  file.managed:
    - name: {{ php_fpm.main_config_path }}
    - source: salt://php_fpm/files/php-fpm.conf
    - template: jinja
    - context:
        sections: {{ php_fpm.config | yaml }}

{% set pool_states = [] %}

{% for name, settings in php_fpm.pools.items() %}
  {%- if settings.config != None %}
    {%- set conf_state_id = 'php_fpm_conf_' ~ loop.index0 %}
    {%- set config_path = salt['file.join'](php_fpm.pool_directory, name + '.conf') %}
{{ conf_state_id }}:
    {%- if settings.enabled %}
  file.managed:
    - name: {{ config_path }}
    - source: salt://php_fpm/files/php-fpm.conf
    - template: jinja
    - context:
        sections:
          {{ name }}:
            {{ settings.config | yaml }}
    - replace: {{ settings.get('overwrite', True) }}
    {%- else %}
  file.absent:
    - name: {{ config_path }}
    {%- endif %}
    {%- do pool_states.append(conf_state_id) %}
  {% endif %}
{% endfor %}

{% macro file_requisites(states) %}
  {%- for state in states %}
- file: {{ state }}
  {%- endfor -%}
{% endmacro %}

{% set service_function = 'running' if php_fpm.service_enabled else 'dead' %}

{% if pool_states|length() > 0 %}
php_fpm_service_reload:
  service.{{ service_function }}:
    - name: {{ php_fpm.service }}
    - enable: {{ php_fpm.service_enabled }}
    - reload: True
    - watch:
      {{ file_requisites(pool_states) | indent(6) }}
    - require:
      {{ file_requisites(pool_states) | indent(6) }}
{% endif %}
