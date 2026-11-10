# Copilot Instructions

This is a PowerShell module that must run on Windows PowerShell 5.1 and PowerShell 7 (no 7-only syntax). For full
conventions, architecture, commands, and contribution workflow, read [AGENTS.md](../AGENTS.md).

Key file locations: `source/Public/` (exported), `source/Private/` (internal), `source/prefix.ps1` (module-level
code), `Tests/`. `./build.ps1` builds the published module into `output/`.

Before committing: `./Tests/test-local.ps1`
