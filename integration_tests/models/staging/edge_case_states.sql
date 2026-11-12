{# States that stress NULL handling and string escaping. Literals go through the package's own
   adapter-aware escaping, so the same model builds on every target. #}
{% set states = [
    (1, 'plain',            'My invoice is wrong, please refund the difference.'),
    (3, 'empty',            ''),
    (4, 'quotes',           'It\'s a "quoted" cancel request, isn\'t it?'),
    (5, 'backslash',        'Path C:\\temp\\new and a regex \\d+ in the ticket'),
    (6, 'newline',          'First line\nSecond line\r\nThird line'),
    (7, 'unicode',          'Réunion café 日本語 🚀'),
] %}
{% for id, name, text in states %}
select {{ id }} as case_id, '{{ name }}' as case_name, {{ dbt_decisions.decisions_string_literal(text) }} as state_text
union all
{% endfor %}
select 2 as case_id, 'null_state' as case_name, cast(null as {{ dbt.type_string() }}) as state_text
