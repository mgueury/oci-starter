# Environment Variables
# The value with ##xxx## will be filled during build.

# Database
{% import "start_sh.j2_macro" as m with context %}
{{ m.env() }}