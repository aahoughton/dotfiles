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

See [1Password](#1password) for how the modes and the gate work.

### Post-install

Update the chezmoi git origin to use `ssh` instead of `https`:
```bash
chezmoi git config remote.origin.url "git@github.com:aahoughton/dotfiles.git"
```

Install Claude Code plugins:
```bash
~/.local/share/chezmoi/scripts/install-claude-plugins.sh
```

Set up the atuin sync server, if this machine hosts it: see
[MAC_README](MAC_README.md).

`scripts/` is in `.chezmoiignore`, so it stays in the source directory and is
never deployed to `$HOME` — always run these by their full path.

IntelliJ note: turn off shell integration in terminal settings.

### Existing machines

The AWS identifiers and the 1Password mode moved into init-time prompts, which
are read once and cached in `~/.config/chezmoi/chezmoi.toml`. A machine set up
before that change won't have them, and will skip `.aws/config` until re-prompted:

```bash
chezmoi init          # re-prompts for the new values, keeps existing answers
chezmoi diff          # check nothing local gets reverted
chezmoi apply
```

`init` also asks for the 1Password mode. Accept the default unless the machine
has no GUI. Note this changes the laptop from `service` to `account`: it had a
hardcoded `service` mode before the mode became a per-machine choice.

History was rewritten on 2026-08-03 to redact AWS identifiers, so every commit
SHA changed. Any clone predating that has an unrelated history and will try to
push the old commits back. On each one:

```bash
cd ~/.local/share/chezmoi
git fetch origin && git reset --hard origin/main
```

## 1Password

### How the bootstrap avoids a chicken-and-egg

`op` is needed to read the vault, but installing `op` is itself part of setup.
Two mechanisms resolve that, and both run before anything can fail on a secret.

A `read-source-state.pre` hook in `.chezmoi.toml.tmpl` runs
`.install-password-manager.sh`, which installs the 1Password **CLI** (brew on
macOS, a versioned zip on Linux) before chezmoi parses `.chezmoiignore`. The
hook path resolves against `$HOME`, so it works from any working directory. A
missing script is a hard error rather than a silent skip.

`.chezmoiignore` then gates the vault-backed files on `scripts/op-ready.sh`,
which answers "can `op` authenticate right now?" under a 15s bound. On
`notready` it skips `.ssh/behemoth_ed25519`, `.ssh/github_ed25519`, and
`.ssh/authorized_keys`, and the apply otherwise succeeds.

The desktop **app** is a brew cask, installed later with the rest of the
packages. So the order is: CLI (hook), every non-secret file, app (cask), sign
in, then secrets on the second apply.

### Modes

`chezmoi init` asks which mode to use, defaulting to `service` for a `server`
machine type and `account` otherwise. The two are mutually exclusive: chezmoi
errors in `account` mode if `OP_SERVICE_ACCOUNT_TOKEN` is set, and in `service`
mode if it isn't. So on an `account` machine, don't export the token.

This is deliberately a separate question from the machine type, which also picks
package sets (`packages_<type>`). behemoth is a `desktop` (it has a GUI) that is
often driven headlessly over ssh, and it stays on `account`.

Service accounts cannot read the built-in Private vault, so anything they need
must live in a custom vault, currently `Service Credentials`.

The mode is read from the config file. `CHEZMOI_ONEPASSWORD_MODE` does **not**
override it; check with `chezmoi dump-config`. To run one apply in a different
mode, copy the config, edit `[onepassword] mode`, and use `chezmoi --config`.

### Over ssh

Applying over ssh lands everything except the three key files above. The cause
is narrower than "the desktop app is unreachable": the CLI has no standalone
account of its own (`op account list` is empty, `~/.config/op/config` shows
`"accounts": null`), so it can only authenticate by delegating to the app. Over
ssh there is nothing to sign in to.

The default posture is to accept that and run the applies that need keys while
sitting at the machine. Two escape hatches exist if that becomes annoying:

- `op account add` configures a standalone CLI account, after which
  `eval $(op signin)` works in an ssh session with `mode = "account"`
  unchanged. This puts the Secret Key on the box and means typing the master
  password into an ssh session. Reversible with `op account forget`. Never
  commit the Secret Key; this repo is public.
- A service account token works headlessly, but needs the keys moved into
  `Service Credentials` and a config swap, since the modes are exclusive.

Every chezmoi command over ssh pays the full `op-ready.sh` timeout, because in
this configuration the check can never return `ready`. `CHEZMOI_OP_TIMEOUT` and
`CHEZMOI_OP_NOTICE_AFTER` tune it.

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
git status --short          # look at untracked files before staging
git add -A && git commit && git push
```

`git add -A` will happily stage anything `chezmoi add` left in the source
directory on that machine, and this repo is public. Check `git status` first —
`chezmoi add` on a file holding tokens or host details creates a source file
that looks like every other one. If a target already has a `modify_` script,
adding it again also produces two source entries for one target, which fails
with `inconsistent state` until one is removed.

## Tools and language management

1. mise handles language versions automatically.
2. uv for python venvs (`uv venv`)
