# Dotfiles

Machine setup using [chezmoi](https://www.chezmoi.io/). These are personal notes 'cause I forget things.

## Start here

A new machine, in order:

1. [Fresh machine setup](#fresh-machine-setup), then
   [Post-install](#post-install), on every OS.
2. **macOS:** [MAC_README.md](MAC_README.md), which lists the manual steps for
   every Mac, then the desktop-only and server-only ones.
   **Linux:** no further notes; the packages come from
   `run_onchange_before_linux-install-packages.sh.tmpl`.

The rest of this file explains how the bootstrap works and how to change it.

## Fresh machine setup

Prerequisites:

- **macOS:** Install [Homebrew](https://brew.sh/)
- **Linux:** `sudo apt-get update && sudo apt-get install -y curl sudo zip unzip`

No SSH key or 1Password sign-in is needed up front: the first pass clones over
https and skips anything it can't decrypt yet.

**Pass 1: everything that isn't a secret.** Install chezmoi and clone the
repo. `init` asks for a machine type and a machine name and writes
`~/.config/chezmoi/chezmoi.toml`; nothing else in your home directory changes
yet.

```bash
# macOS: chezmoi from Homebrew, which keeps it updated from here on
brew install chezmoi
chezmoi init aahoughton/dotfiles

# Linux: the installer puts chezmoi in ./bin, so run it from ~
cd ~ && sh -c "$(curl -fsLS get.chezmoi.io)" -- init aahoughton/dotfiles
```

Before applying, decide whether this machine skips any casks (macOS). To skip
some, list them in `~/.config/chezmoi/skip-casks`, one per line, named exactly
as in `.chezmoidata/packages.yaml` or `packages_<type>.yaml` under
`~/.local/share/chezmoi` (see [Conventions](#conventions)). Then apply:

```bash
chezmoi apply          # Linux: ~/bin/chezmoi apply
```

This installs packages (including 1Password) and deploys every config that
doesn't depend on the vault. The init answers are stored, and a plain
`chezmoi init` never asks again. To change one later, run
`chezmoi init --prompt`, which repeats every question, or edit
`~/.config/chezmoi/chezmoi.toml`.

**Pass 2: the secrets.** Sign in to 1Password, then:

```bash
# open the 1Password app, then Settings > Developer >
# "Integrate with 1Password CLI" to enable Touch ID unlock
op signin          # approve in the app; each new shell needs this once
op whoami          # should print your account
chezmoi apply
```

The vault-backed files (SSH keys and the rest) land on this second pass. On
the server, so do the server-only files: chezmoi decides what to install
before pass 1 gives the machine its name, so pass 1 does not know yet that it
is the server. `.chezmoiignore` checks
whether `op` can authenticate on every apply, so nothing needs re-running beyond
`chezmoi apply` itself.

See [1Password](#1password) for how the gate works.

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
`notready` it skips every file listed in that block of `.chezmoiignore` (the
keys, the AWS config, and anything else read from the vault), and the apply
otherwise succeeds.

The desktop **app** is a brew cask, installed later with the rest of the
packages. So the order is: CLI (hook), every non-secret file, app (cask), sign
in, then secrets on the second apply.

### Sessions

chezmoi reads the vault with whatever `op` session the shell has
(`[onepassword] mode = "account"`): the desktop app's CLI integration, or a
standalone CLI account signed in with `eval (op signin)` (see "Over ssh"). The
gate only asks `op whoami`, so a machine without the app, such as a headless
Linux box, gets the vault-backed files once that account is added and signed
in. With no session it gets every non-secret file and none of the vault ones.
Everything chezmoi reads lives in the `dotfiles` vault.

chezmoi refuses to run in this mode if `OP_SERVICE_ACCOUNT_TOKEN` is set, so
don't export one.

### Over ssh

With the app integration on, `op` in an ssh session still goes through the
desktop app, so its approval prompt appears on that machine's screen rather
than in your terminal. In ssh sessions fish sets
`OP_BIOMETRIC_UNLOCK_ENABLED=false` (`conf.d/op_ssh.fish`), which makes `op`
use a standalone CLI account and ask for the master password instead:

```
eval (op signin)
chezmoi apply
```

`op signin` prints a session token as a shell command; `eval` puts it in the
current shell, and it expires after 30 minutes idle.

Each machine you ssh into needs the standalone account once. While the app
integration is on, `op account add` refuses unless that variable is set, so
run it from an ssh session or prefix it:

```
OP_BIOMETRIC_UNLOCK_ENABLED=false op account add --address <account>.1password.com --email <email>
```

It asks for the Secret Key and the master password, and stores the Secret Key
on the box (in `~/.config/op/config`; never commit or print it, this repo is
public). `op account forget` removes it.

Without a signed-in session, an ssh apply lands everything except the
vault-backed files above. With the variable set, `op-ready.sh` gets its answer
in a few seconds; without it, every chezmoi command waits out the full
timeout. `CHEZMOI_OP_TIMEOUT` and `CHEZMOI_OP_NOTICE_AFTER` tune it.

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
| Homebrew casks | `~/.config/chezmoi/skip-casks` (see below) |

`skip-casks` sits next to `chezmoi.toml` and lists casks to leave out of
`brew bundle` on this machine, one per line, `#` for comments. Write each name
exactly as `.chezmoidata` lists it, including the full `owner/tap/name` for a
tap cask. Changing which casks it lists re-runs the install script on the next
apply. It does not uninstall anything; run `brew uninstall --cask <name>` for
that.

A name that is not in this machine's cask lists (shared plus its machine type),
such as a typo or a cask later removed from `.chezmoidata`, is ignored, with a
warning on every `chezmoi apply`, `status` and `diff` until the file is fixed.

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

- `.chezmoitemplates/agents-global.md` — global agent instructions, shared by
  Claude Code (`~/.claude/CLAUDE.md`), Codex (`~/.codex/AGENTS.md`), pi
  (`~/.pi/agent/AGENTS.md`), and Antigravity (`~/.gemini/AGENTS.md`). Each target
  is a template that includes the shared text; instructions for one agent go after
  the include in that agent's template. The targets are generated, so edits made
  on a machine (including through `/memory`) are overwritten by the next apply;
  copy them into the template first.
- `dot_agents/private_writing-voice.md.tmpl` — writing-voice guide from 1Password,
  deployed to `~/.agents/writing-voice.md`, where the shared instructions point.
- `private_dot_claude/skills/` — Claude Code skills, deployed to `~/.claude/skills/`:
  `arch-review` (whole-repo structural audit), `branch-review` (pre-merge checks
  that complement `/code-review`), `pare-docs` (cuts bloat from prose docs).
- `private_dot_claude/agents/` — Claude Code subagents, deployed to
  `~/.claude/agents/`: `diff-reviewer` (reviews a staged diff or sha range from
  fresh context, independent of whoever wrote it).
- `private_dot_claude/hooks/` — deployed to `~/.claude/hooks/` and wired to
  nothing globally. `require-review-before-push.sh` gates `git push` on a
  recorded review; it is opted into one repo at a time from that repo's own
  `.claude/settings.local.json`, so the set of gated repos stays out of this
  public tree. This repo is the exception: it opts in from its committed
  `.claude/settings.json`. The script's header has the JSON and the reasoning.
- `personal/`, `src/`, `tmp/` — empty directories created on every machine, kept
  by `.keep`.
- `Desktop/` — symlinks to `$HOME` and `~/tmp` for reachability from file dialogs.

## Making changes

Package lists are in `.chezmoidata/packages.yaml`. The install scripts (`run_onchange_*-install-packages.sh.tmpl`) will re-run when that file changes.

Global tools (Node itself and Node CLIs) are in the `mise:` list in the same
file, installed by `run_onchange_after_install-mise-tools.sh.tmpl` with
`mise use -g`. That adds entries to `~/.config/mise/config.toml` without owning
it, so tools added on one machine stay there. Add Node CLIs to that list rather
than using `npm install -g`.

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
