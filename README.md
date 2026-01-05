# Dotfiles

Machine setup using [chezmoi](https://www.chezmoi.io/). These are personal notes 'cause I forget things.

## Fresh machine setup

**macOS:**

Prerequisites:

1. Install [Homebrew](https://brew.sh/), get it setup for ZSH just long enough
   to install chezmoi.
2. `export OP_SERVICE_ACCOUNT_TOKEN="<TOKEN>"`

Install and apply:
```bash
brew install chezmoi
chezmoi init https://github.com/aahoughton/dotfiles.git
chezmoi apply
```

**Linux:**

Prerequisites:
```bash
sudo apt-get update
sudo apt-get install -y curl sudo zip unzip
```

Install and apply:
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
chezmoi init https://github.com/aahoughton/dotfiles.git
chezmoi apply
```

This installs packages and deploys configs; SSH keys and AWS credentials get templated from 1Password.

### Post-install

**General**

Update the chezmoi git origin to use `ssh` instead of `https`:
```bash
chezmoi git config remote.origin.url "git@github.com:aahoughton/dotfiles.git"
```

**macOS:**

Set Fish as the default shell:

```bash
echo "$(brew --prefix)/bin/fish" | sudo tee -a /etc/shells
chsh -s "$(brew --prefix)/bin/fish"
```

**Linux:**
```bash
echo /usr/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/bin/fish
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

