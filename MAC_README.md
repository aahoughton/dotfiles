# macOS Post-Setup

After running the bootstrap from [README.md](README.md), the following are handled automatically:

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
4. LaunchBar: hide dock icon
5. Backblaze: install manually (cask doesn't work) and exclude OrbStack data directory
6. **Behemoth only:** Start OrbStack, then run `setup-atuin-server` to start the atuin sync server. Then `atuin register` / `atuin login` on each machine.

## Optional Software

Not included in the automated install — evaluate per-machine:

- **Transcription:** [superwhisper](https://superwhisper.com) or [Fluid Voice](https://github.com/altic-dev/FluidVoice)
- **Menu bar management:** Barbee (App Store)
