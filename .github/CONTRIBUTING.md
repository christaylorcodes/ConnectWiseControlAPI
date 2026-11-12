# Contributing to ConnectWiseControlAPI

:+1::tada: First off, thanks for taking the time to contribute! :tada::+1:

The following is a set of guidelines for contributing. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document, or anything else in a pull request.

## Table Of Contents

[I don't want to read this whole thing, I just have a question!!!](#i-dont-want-to-read-this-whole-thing-i-just-have-a-question)

[How Can I Contribute?](#how-can-i-contribute)

- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

[AI Contributors](#ai-contributors)

[Styleguides](#styleguides)

- [Git Commit Messages](#git-commit-messages)
- [Powershell Styleguide](#powershell-styleguide)
- [Documentation Styleguide](#documentation-styleguide)

## I don't want to read this whole thing I just have a question

> **Note:** *Please don't file an issue to ask a question.* You'll get faster results by using the resources below.

Join a community Slack team:

- [Join the MSPGeek Slack Team](https://join.mspgeek.com/)
- [Join the PowerShell Slack Team](https://powershell.slack.com/join/shared_invite/zt-eodd93as-RHYl6s~9XH8FNyE09M7zmA#/)

    - Even though Slack is a chat service, sometimes it takes several hours for community members to respond — please be patient!
    - Use a channel that looks appropriate for general questions or discussion
    - There are many other channels available, check the channel list
    - Send me a DM if you want, @CTaylor

## How Can I Contribute

### Reporting Bugs

This section guides you through submitting a bug report. Following these guidelines helps maintainers and the community understand your report :pencil:, reproduce the behavior :computer: :computer:, and find related reports :mag_right:.

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible. Fill out template, the information it asks for helps us resolve issues faster.

> **Note:** If you find a **Closed** issue that seems like it is the same thing that you're experiencing, open a new issue and include a link to the original issue in the body of your new one.

#### Before Submitting A Bug Report

- **Check the help.** The [README](../README.md), the [function pages](../ConnectWiseControlAPI_Functions.md), `Get-Help about_ConnectWiseControlAPI` and the [changelog](../CHANGELOG.md) (see "Breaking changes") may explain the problem.
- **Check the [MSPGeek Slack Team](https://join.mspgeek.com/)** for help from the community.

#### How Do I Submit A (Good) Bug Report

Bugs are tracked as [GitHub issues](https://docs.github.com/en/issues). After you've determined which repository your bug is related to, create an issue on that repository and provide the following information by filling in the template.

Explain the problem and include additional details to help maintainers reproduce the problem:

- **Use a clear and descriptive title** for the issue to identify the problem.
- **Describe the exact steps which reproduce the problem** in as many details as possible.
- **Provide specific examples to demonstrate the steps**. Include links to files or GitHub projects, or copy/pasteable snippets, which you use in those examples. If you're providing snippets in the issue, use [Markdown code blocks](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks).
- **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
- **Explain which behavior you expected to see instead and why.**

Provide more context by answering these questions:

- **Did the problem start happening recently** (e.g. after updating to a new version) or was this always a problem?
- **Can you reliably reproduce the issue?** If not, provide details about how often the problem happens and under which conditions it normally happens.

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion, including completely new features and minor improvements to existing functionality. Following these guidelines helps maintainers and the community understand your suggestion :pencil: and find related suggestions :mag_right:.

Before creating enhancement suggestions, please check existing suggestions as you might find out that you don't need to create one. When you are creating an enhancement suggestion, please include as many details as possible. Fill in the template, including the steps that you imagine you would take if the feature you're requesting existed.

#### How Do I Submit A (Good) Enhancement Suggestion

Enhancement suggestions are tracked as [GitHub issues](https://docs.github.com/en/issues). Create an issue and provide the following information:

- **Use a clear and descriptive title** for the issue to identify the suggestion.
- **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
- **Provide specific examples to demonstrate the steps**. Include copy/pasteable snippets which you use in those examples, as [Markdown code blocks](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks).
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
- **Explain why this enhancement would be useful** to most users and isn't something that belongs in your own script.
- **List some other text examples where this enhancement exists.**
- **Specify which version of the module you're using.**
- **Specify the name and version of the OS you're using.**

## AI Contributors

This project welcomes contributions from AI coding agents. AI agents follow the same quality standards as human contributors. See [AGENTS.md](../AGENTS.md) for development instructions and conventions.

## Styleguides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")

- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")

- Limit the first line to 72 characters or less

- Reference issues and pull requests liberally after the first line

- Consider starting the commit message with an applicable emoji:
    - :art: `:art:` when improving the format/structure of the code
    - :racehorse: `:racehorse:` when improving performance
    - :non-potable_water: `:non-potable_water:` when plugging memory leaks
    - :memo: `:memo:` when writing docs
    - :checkered_flag: `:checkered_flag:` when fixing something on Windows
    - :bug: `:bug:` when fixing a bug
    - :fire: `:fire:` when removing code or files
    - :green_heart: `:green_heart:` when fixing the CI build
    - :white_check_mark: `:white_check_mark:` when adding tests
    - :lock: `:lock:` when dealing with security
    - :arrow_up: `:arrow_up:` when upgrading dependencies
    - :arrow_down: `:arrow_down:` when downgrading dependencies
    - :shirt: `:shirt:` when removing linter warnings

### PowerShell Styleguide

- Follow the repo's [PowerShell style guide](PowerShell-StyleGuide.md); read the note at its top first. Code must run on Windows PowerShell 5.1.
- Run `./Tests/test-local.ps1` before you open a pull request. It runs the same checks as CI.

### Documentation Styleguide

- Function help is written as comment-based help in the function's file under `source/Public/`.
- `Docs/`, `ConnectWiseControlAPI_Functions.md` and the help file in `source/en-US/` are generated from it with [platyPS](https://github.com/PowerShell/platyPS). Don't edit them by hand: run `./Build/Update-Help.ps1` and commit the result.
