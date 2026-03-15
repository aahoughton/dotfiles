# Dotfiles

Machine setup using [chezmoi](https://www.chezmoi.io/). These are personal notes 'cause I forget things.

## Fresh machine setup

Prerequisites:

- SSH key added (`ssh-add`)
- `export OP_SERVICE_ACCOUNT_TOKEN="<TOKEN>"`
- **macOS:** Install [Homebrew](https://brew.sh/)
- **Linux:** `sudo apt-get update && sudo apt-get install -y curl sudo zip unzip`

Bootstrap:
```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply aahoughton/dotfiles --ssh
```

This installs packages and deploys configs; SSH keys and AWS credentials get templated from 1Password.

### Post-install

Update the chezmoi git origin to use `ssh` instead of `https`:
```bash
chezmoi git config remote.origin.url "git@github.com:aahoughton/dotfiles.git"
```

Install Claude Code plugins:
```bash
~/.local/share/chezmoi/scripts/install-claude-plugins.sh
```

Set up atuin sync server (if this machine will host it):
```bash
~/.local/share/chezmoi/scripts/setup-atuin-server.sh
```

IntelliJ note: turn off shell integration in terminal settings.

## Making changes

Package lists are in `.chezmoidata/packages.yaml`. The install scripts (`run_onchange_*-install-packages.sh.tmpl`) will re-run when that file changes.

Commit from the source directory:
```bash
cd ~/.local/share/chezmoi
git add -A && git commit && git push
```

## Tools and language management

1. mise handles language versions and automatically.
2. uv for python venvs (`uv venv`)
