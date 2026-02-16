# Initial Mac Setup

## System Settings

1. Change machine name (System Settings > General > About > Name)
2. Turn on SSH (System Settings > General > Sharing > Remote Login)
3. Use Quad9 DNS (9.9.9.9, System Settings > Network > Wi-Fi > <SSID> > Details)
4. Remove spotlight keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts... > Spotlight)
5. Use Function Keys (System Settings > Keyboard > Keyboard Shortcuts... > Function Keys)
6. Turn on Tap-to-Click (System Settings > Trackpad > Tap to Click)
7. Show Battery Percentage (System Settings > Menu Bar > Battery > Battery Options...)
8. Show Sound Settings (System Settings > Menu Bar > Sound)

## Additional

- go through each installed cask and finalize setup
- coteditor: set it as handler for txt and md files
- dock: automatically show / hide
- dock: do not show recent / suggested
- launcher: hide dock icon
- backblaze: install manually (cask doesn't appear to work) and add orbstack data directory to excluded
- menubar spacing:
  ```
  defaults -currentHost write -globalDomain NSStatusItemSpacing -int 0
  defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 0
  killall ControlCenter
  ```
