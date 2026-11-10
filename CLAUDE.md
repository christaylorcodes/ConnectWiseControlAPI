# CLAUDE.md

[AGENTS.md](AGENTS.md) is the single source of truth for all AI agents: project context, architecture, commands,
code conventions and contribution rules. It is imported here so it is always loaded:

@AGENTS.md

## Mandatory Validation

**Before every commit**, run:

```powershell
./Tests/test-local.ps1
```

It runs PSScriptAnalyzer, `Test-ModuleManifest`, Pester under PowerShell 7 **and** Windows PowerShell 5.1, and the
docs-drift check, the same stages as CI. Do not commit until all pass. CI is a safety net only; failures should
never first appear there.
