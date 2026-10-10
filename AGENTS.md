# AGENTS.md

chezmoi source for my dotfiles. This repo is public.

## Branches

No feature branches. Commit directly to main. Pushing still needs my go-ahead.

## Editing

- Edit files here, never the targets under `~`, then run `chezmoi apply <target>` and
  confirm `chezmoi diff <target>` is empty.
- Files that belong to the repo but not to `~` (docs, this file, scripts) must be listed
  in `.chezmoiignore`, or chezmoi will install them into the home directory.

## Security

The only personal information allowed in this repo is my name, my email address, and
minimal detail about my home network (machine hostnames). Secrets and host-specific
values come from 1Password or init prompts.

Before every commit, review the staged diff and the commit message for anything beyond
that, including:

- Credentials: keys, tokens, passwords, private key material, auth files.
- Network detail: IP addresses, MAC addresses, Wi-Fi names, tailnet or internal domain
  names, ports of services I expose.
- Account identifiers: cloud account IDs, usernames on other services, phone numbers,
  street addresses.
- Employer or client names, and paths or config that reveal them.

If anything turns up, or you're unsure whether it counts, stop and ask before committing.

Two hooks back this up. A git pre-commit hook runs gitleaks on staged changes for keys
in known formats. A Claude hook holds `git push` until the outgoing changes are
reviewed; in this repo that review covers the list above, over both diffs and commit
messages.
