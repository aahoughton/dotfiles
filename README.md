# Dotfiles

Machine setup using [chezmoi](https://www.chezmoi.io/). These are personal notes 'cause I forget things.

## Fresh machine setup

Prerequisites:

- **macOS:** Install [Homebrew](https://brew.sh/)
- **Linux:** `sudo apt-get update && sudo apt-get install -y curl sudo zip unzip`

No SSH key or 1Password token is needed up front — the first pass clones over
https and skips anything it can't decrypt yet.

**Pass 1 — everything that isn't a secret:**
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply aahoughton/dotfiles
```

This installs packages (including 1Password) and deploys every config that
doesn't depend on the vault. It will ask for a machine type, a machine name, and
the AWS account ID and SSO start URL (leave both blank to skip `.aws/config`).

**Pass 2 — the secrets.** Sign in to 1Password, then:

```bash
# laptop/desktop: open the 1Password app, then Settings > Developer >
# "Integrate with 1Password CLI" to enable Touch ID unlock
op whoami          # should print your account

# server (headless): a service account token instead
export OP_SERVICE_ACCOUNT_TOKEN="<TOKEN>"

chezmoi apply
```

SSH keys and `authorized_keys` land on this second pass. `.chezmoiignore` checks
whether `op` can authenticate on every apply, so nothing needs re-running beyond
`chezmoi apply` itself.

Interactive machines use 1Password's `account` mode (desktop app, Touch ID);
`server` machines use `service` mode. That's picked from the machine type
answered at init. Note service accounts cannot read the built-in Private vault —
anything they need must live in a custom vault, currently `Service Credentials`.

### Post-install

Update the chezmoi git origin to use `ssh` instead of `https`:
```bash
chezmoi git config remote.origin.url "git@github.com:aahoughton/dotfiles.git"
```

### Existing machines

The AWS identifiers and the 1Password mode moved into init-time prompts, which
are read once and cached in `~/.config/chezmoi/chezmoi.toml`. A machine set up
before that change won't have them, and will skip `.aws/config` until re-prompted:

```bash
chezmoi init          # re-prompts for the new values, keeps existing answers
chezmoi apply
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
