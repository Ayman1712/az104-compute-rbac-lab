---
description: "Use when creating or modifying Bicep files in this project. Explain deployment parameters, resources, module wiring, and non-obvious properties with concise comments."
applyTo: "**/*.bicep"
---
# Bicep explanation comments

- Add concise educational comments that explain the purpose of declarations, resource configuration, module parameters, and dependencies.
- For orchestration templates, explain the end-to-end flow: deployment scope, parameter sources and overrides, module scopes, parameter/output wiring, and implicit dependencies between resources or modules.
- Explain how a parameter file is used from the Bicep entry point; do not put comments in strict JSON parameter files.
- Prefer comments before meaningful properties or logical blocks; do not add comments to every brace or restate syntax that is self-evident.
- Keep comments accurate as behavior changes, and avoid changing deployment behavior just to add explanation.
