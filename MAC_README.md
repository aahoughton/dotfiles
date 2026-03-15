# Initial Mac Setup

After `chezmoi init && chezmoi apply`, the following are handled automatically:

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

1. Use Quad9 DNS (System Settings > Network > Wi-Fi > <SSID> > Details)
2. Go through each installed cask and finalize setup
3. CotEditor: set as handler for .txt and .md files
4. LaunchBar: hide dock icon
5. Backblaze: install manually (cask doesn't work) and exclude OrbStack data directory
