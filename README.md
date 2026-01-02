# Dotfiles

Machine setup using [chezmoi](https://www.chezmoi.io/).

## Fresh machine setup

**macOS:**
Install [Homebrew](https://brew.sh/) first, then:
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

This installs packages and deploys configs. SSH keys and AWS credentials get templated from 1Password.

### 1Password setup

We use 1Password service accounts to template secrets. Set this before running `chezmoi apply`:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="<TOKEN>"
```

The hook script will install the `op` CLI if it's missing.

### Post-install

Set Fish as the default shell:

**macOS:**
```bash
echo "$(brew --prefix)/bin/fish" | sudo tee -a /etc/shells
chsh -s "$(brew --prefix)/bin/fish"
```

Some apps need manual login (1Password, Backblaze, Tailscale, etc.). App Store apps like UpNote and Barbee need manual install.

**Linux:**
```bash
echo /usr/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/bin/fish
```

Firefox extensions I use: 1Password, Facebook Container, Privacy Badger, Pinboard.

IntelliJ note: turn off shell integration in terminal settings.

## Making changes

Package lists are in `.chezmoidata/packages.yaml`. The install scripts (`run_onchange_*-install-packages.sh.tmpl`) will re-run when that file changes.

Commit from the source directory:
```bash
cd ~/.local/share/chezmoi
git add -A && git commit && git push
```

## Tools and language management

mise handles language versions and automatically.
uv for python venvs (`uv venv`)

