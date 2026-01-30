# Environment Variables
# The values between ## will be filled during build.

{%- import "start_sh.j2_macro" as m with context %}
{{ m.env() }}
