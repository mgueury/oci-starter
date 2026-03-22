# Generic Implementation Rules (Syntax & Conventions)

These rules describe implementation conventions of the `src/` codebase, without hard-coding business logic.

## Shell scripting conventions

- Use Bash for automation (`#!/usr/bin/env bash` or `#!/bin/bash`).
- Resolve script location with `BASH_SOURCE[0]` and `cd` to script directory before relative operations.
- Source environment bridges (`env.sh`, `compute/tf_env.sh`) before running dependent commands.
- Keep scripts rerunnable and explicit (`install.sh`, `start.sh`, `build_*.sh`, `db_init.sh`).

## Application code 

- The application code lives under `src/app`.
- Configuration is read from environment variables (for example `TF_VAR_compartment_ocid`, DB credentials, OCI settings).

## UI conventions

- UI is static web content in `src/ui/ui/` (HTML/CSS/JS + assets).
- Front-end JavaScript uses `fetch` and relative URLs for backend integration.
- Keep chat behavior in `chat.js` and markup in `index.html`.

## Terraform conventions

- Terraform files are modularized by concern (`provider.tf`, `network.tf`, `compute.tf`, `atp.tf`, `output.tf`, etc.).
- Use Terraform outputs/environment export flow to feed runtime shell and app setup.