# Mt Messenger Ecology Figure Pipeline

<!-- badges: start -->
![Python Version](<https://img.shields.io/badge/python-3.13.2-green>)
[![Confluence](<https://img.shields.io/badge/Not_Configured-Confluence-lightgrey>)](<https://tonkintaylor.atlassian.net/wiki/home>)
![Licence](<https://img.shields.io/badge/licence-proprietary-red>)
[![Ruff](<https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json>)](<https://github.com/astral-sh/ruff>)
[![Jira](<https://img.shields.io/badge/Not_Configured-Jira-lightgrey>)](<https://tonkintaylor.atlassian.net/jira/projects>)
<!-- badges: end -->

## Introduction

Automated figure generation for regular reporting on Mt Messenger.

Job number: 100181.4600

## Getting Started on Development

### Installing the Python environment and Configuring VS Code

Run the following command in Windows Powershell to configure the environment and
your VS Code settings (your current directory should be the root of the repo):

```Powershell
./tasks/dev_sync.ps1
```

## Other Development Tasks

### Adding a dependency (or regenerating the requirements files.)

Add a lowercase name of the package to the [project].dependencies section of the
`pyproject.toml` file. You will then need to re-generate the requirements files and
install the package via:

```Powershell
./tasks/dev_sync.ps1
```

### Releasing a package version

Run the following command in Windows Powershell to release a new version of the package:

```Powershell
./tasks/release.ps1
```

The branch will be automatically created and pushed to the cloud, ready for a PR to be
created.

## Adding to changelog

Add a new file at `doc/whatsnew/{issue_num}.{entry_type}.md` where `{issue_num}` is
the JIRA issue number being worked on, and `{entry_type}` is one of `feature`, `bugfix`,
`doc`, `removal`, `newhome`, `test`, or `devconfig`.

In the file provide a description of the change that will appear in the changelog.
