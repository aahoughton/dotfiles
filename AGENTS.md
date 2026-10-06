# AGENTS.md

chezmoi source for my dotfiles. This repo is public.

## Branches

No feature branches. Commit directly to main. Pushing still needs my go-ahead.

## Editing

- Edit files here, never the targets under `~`, then run `chezmoi apply <target>` and
  confirm `chezmoi diff <target>` is empty.
- Files that belong to the repo but not to `~` (docs, this file, scripts) must be listed
  in `.chezmoiignore`, or chezmoi will install them into the home directory.
- No secrets or host-specific values in committed files; those come from 1Password or
  init prompts.
