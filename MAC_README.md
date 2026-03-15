# Initial Mac Setup

## Bootstrap

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply aahoughton/dotfiles --ssh
```

Prerequisites: Homebrew installed, SSH key added (`ssh-add`).

## Automated

After the bootstrap above, the following are handled automatically:

- Machine name (prompted during `chezmoi init`)
- Homebrew packages and casks
- Default shell set to fish
- SSH / Remote Login enabled
- Dock: autohide, hide recents
- Trackpad: tap to click
- Function keys as standard function keys
- Spotlight keyboard shortcuts disabled
- Battery percentage in menu bar
- Sound in menu bar
- Menubar spacing (compact)

## Manual Steps

1. Disable Apple's built-in password manager: System Settings > Passwords > Password Options > uncheck "Autofill Passwords and Passkeys"
2. Use Quad9 DNS (System Settings > Network > Wi-Fi > <SSID> > Details)
3. Go through each installed cask and finalize setup
4. CotEditor: set as handler for .txt and .md files
5. LaunchBar: hide dock icon
6. Backblaze: install manually (cask doesn't work) and exclude OrbStack data directory
7. **Behemoth only:** Start OrbStack, then run `setup-atuin-server` to start the atuin sync server. Then `atuin register` / `atuin login` on each machine.
