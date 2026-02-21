# Grab

**Grab** is a minimalist, ultra-fast CLI tool to search and clone GitHub projects without typing URLs. Built on top of [GitHub CLI (`gh`)](https://cli.github.com/), it features fuzzy search, smart picking, and automatic updates.

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/TMCooper/Grab)](https://github.com/TMCooper/Grab/releases)
[![GitHub license](https://img.shields.io/github/license/TMCooper/Grab)](https://github.com/TMCooper/Grab/blob/main/LICENSE)

## Core Features
- **Smart Fuzzy Search**: Case-insensitive, ignores separators (`-`, `_`, `.`).
- **User & Org Support**: Clone from your account or any other GitHub user/organization (`-o`).
- **Branch Support**: Clone specific branches or pick one interactively (`-b`).
- **Clean View**: Truncated descriptions by default, full view with `-d`.
- **Modern UI**: Professional terminal output with headers and status colors.
- **Manual Update**: Notifies you if a new version is available (`--update`).

## Installation
```bash
curl -sSL https://raw.githubusercontent.com/TMCooper/Grab/main/grab.sh | bash -s -- --install
```
*Restart your terminal or run `source ~/.bashrc` after installing.*

## Quick Start

### Basic Cloning
```bash
grab my project                      # Search & clone your own repo
grab -o TMCooper Anime Downloader    # Search in another user's repos
grab -o vercel next                  # Search in an organization's repos
```

### Branch Management
```bash
grab myrepo -b dev       # Clone 'dev' branch directly
grab myrepo -b           # Pick a branch from an interactive menu
```

### Exploration & Listing
```bash
grab -l                  # List your repos (clean view)
grab -l -o microsoft -d  # List Microsoft repos with full descriptions
```

## Requirements
- [GitHub CLI (`gh`)](https://cli.github.com/) authenticated (`gh auth login`).
- Standard tools: `bash`, `curl`, `grep`, `sed`, `tr`.

---
Made by [TMCooper](https://github.com/TMCooper)
