# Grab

**Grab** is a minimalist, ultra-fast CLI tool designed to search and clone GitHub repositories without ever leaving your terminal or typing a full URL. Built on top of the [GitHub CLI (`gh`)](https://cli.github.com/), it adds fuzzy search and smart disambiguation to make your workflow seamless.

[![GitHub license](https://img.shields.io/github/license/TMCooper/Grab)](https://github.com/TMCooper/Grab/blob/main/LICENSE)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/TMCooper/Grab)](https://github.com/TMCooper/Grab/releases)

## Features

- **Fuzzy Matching**: Search by keywords. Case? Separators like `-` and `_`? `Grab` doesn't care. It finds what you mean.
- **Fast Search**: Instant results across your own repositories.
- **Owner Support**: Search and clone from any user or organization with the `-o` flag.
- **Smart Selection**: If multiple repositories match your query, `Grab` interactive menu lets you pick the right one in one keystroke.
- **Auto-Update**: Stays up to date automatically. It checks for new versions and updates itself in place.
- **Unix-Style UI**: Clean, colored, and professional output.

## Installation

Just run this one-liner to install `grab` to your `~/.local/bin`:

```bash
curl -sSL https://raw.githubusercontent.com/TMCooper/Grab/main/grab.sh | bash -s -- --install
```

*Don't forget to restart your terminal or run `source ~/.bashrc` (or `~/.zshrc`) after installation.*

## Usage

### Clone your own projects
```bash
grab anime downloader    # Matches 'Anime-Sama-Downloader'
grab rias bot           # Matches 'Rias-Gremory-Bot'
```

### Clone from others
```bash
grab -o microsoft terminal    # Search 'terminal' in Microsoft's repos
grab -o torvalds linux        # You know what this does
```

### Explore
```bash
grab -l                  # List all your repositories
grab -l -o vercel        # List all public repositories of Vercel
grab -o JetBrains        # List all JetBrains repos and pick one to clone
```

## 🛠️ Requirements

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated (`gh auth login`).
- `bash`, `curl`, `grep`, `sed`, `tr`.

## Contributing

Feel free to open issues or pull requests if you have suggestions for new features or improvements!

---
Developed by [TMCooper](https://github.com/TMCooper)
