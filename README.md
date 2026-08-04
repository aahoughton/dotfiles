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

Install Claude Code plugins:
```bash
~/.local/share/chezmoi/scripts/install-claude-plugins.sh
```

Set up atuin sync server (if this machine will host it):
```bash
~/.local/share/chezmoi/scripts/setup-atuin-server.sh
```

`scripts/` is in `.chezmoiignore`, so it stays in the source directory and is
never deployed to `$HOME` — always run these by their full path.

IntelliJ note: turn off shell integration in terminal settings.

### Existing machines

The AWS identifiers and the 1Password mode moved into init-time prompts, which
are read once and cached in `~/.config/chezmoi/chezmoi.toml`. A machine set up
before that change won't have them, and will skip `.aws/config` until re-prompted:

```bash
chezmoi init          # re-prompts for the new values, keeps existing answers
chezmoi apply
```

History was rewritten on 2026-08-03 to redact AWS identifiers, so every commit
SHA changed. Any clone predating that has an unrelated history and will try to
push the old commits back. On each one:

```bash
cd ~/.local/share/chezmoi
git fetch origin && git reset --hard origin/main
```

## Conventions

Three patterns worth keeping to. All exist because something other than chezmoi
also writes to these files, and fighting it for ownership produces permanent
drift in `chezmoi status`.

**Machine-local overrides.** Anything that shouldn't be shared across machines —
or shouldn't be in a public repo — goes in an unmanaged local file that the
managed one includes:

| Managed | Local, unmanaged |
|---|---|
| `~/.ssh/config` | `~/.ssh/config.local` (included first, so it can override) |
| fish config | any `~/.config/fish/conf.d/*.fish` chezmoi doesn't own |

`.ssh/config.local` is listed in `.chezmoiignore` so `chezmoi add` refuses it.
Prefer this over editing a managed file directly — that edit will be reverted on
the next apply, and `chezmoi add` would publish it.

**Files another tool also writes.** Use a `modify_` script, which receives the
current file on stdin and writes the new contents to stdout. `~/.claude/settings.json`
works this way: `private_dot_claude/modify_settings.json` enforces a few keys via
`jq` and passes everything else through, so Claude Code keeps ownership of
`enabledPlugins` and of any key a future version adds.

**One-time installer noise.** Installers that append to shell rc files (`lms` did)
are not worth a mechanism — fold the change into the line already managed here and
delete the appended block.

## Layout

- `private_dot_claude/skills/` — Claude Code skills, deployed to `~/.claude/skills/`:
  `arch-review` (whole-repo structural audit), `branch-review` (pre-merge checks
  that complement `/code-review`), `pare-docs` (cuts bloat from prose docs).
- `personal/`, `src/`, `tmp/` — empty directories created on every machine, kept
  by `.chezmoikeep`.
- `Desktop/` — symlinks to `$HOME` and `~/tmp` for reachability from file dialogs.

## Making changes

Package lists are in `.chezmoidata/packages.yaml`. The install scripts (`run_onchange_*-install-packages.sh.tmpl`) will re-run when that file changes.

If `chezmoi apply` reports a file "has changed since chezmoi last wrote it", something
edited it outside chezmoi. Check what would be lost before overriding:

```bash
chezmoi diff ~/.some-file     # lines prefixed - would be removed
chezmoi apply --force ~/.some-file
```

If the change is worth keeping, move it into the source directory or into a
machine-local override rather than re-applying over it each time.

Commit from the source directory:
```bash
cd ~/.local/share/chezmoi
git add -A && git commit && git push
```

## Tools and language management

1. mise handles language versions automatically.
2. uv for python venvs (`uv venv`)
