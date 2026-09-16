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
6. **Behemoth only:** Start OrbStack, then run `~/.local/share/chezmoi/scripts/setup-atuin-server.sh` to start the atuin sync server. Then `atuin register` / `atuin login` on each machine.
7. **Behemoth only:** Local LLM. `~/.config/llama/` and `~/.pi/` arrive with the
   first apply; the weights and the API key do not.
   - Recover the server API key. It is deliberately unmanaged, because this repo
     is public:
     ```
     op read "op://Service Credentials/behemoth_llama-server/credential" \
       > ~/.config/llama/api-key && chmod 600 ~/.config/llama/api-key
     ```
   - Restore the weights (~30 GB, archive first, falling back to Hugging Face,
     SHA-256 verified against `models.lock.yaml`): `~/.config/llama/restore-models.sh`
   - Start the server: `~/.config/llama/llama-serve.sh`
   - Expose it to the tailnet. The server binds loopback, so without this only
     this machine can reach it. Persists across reboots:
     ```
     tailscale serve --bg --http=8080 http://127.0.0.1:8080
     ```
     Then it answers at `http://behemoth:8080` from any tailnet device, and
     nowhere on the LAN. Use `--https=443` instead once HTTPS certs are enabled
     for the tailnet; they are not today, and `tailscale serve --https` hangs on
     cert provisioning rather than reporting why.
   - Install the coding agent. This one is npm, not Homebrew:
     `npm install -g @earendil-works/pi-coding-agent`
     Reinstall it after a `brew upgrade node`, which can clear the global prefix.
     node is a brew formula rather than a mise runtime for this reason; a mise
     version switch would take the global CLIs with it.
## Optional Software

Not included in the automated install — evaluate per-machine:

- **Transcription:** [superwhisper](https://superwhisper.com) or [Fluid Voice](https://github.com/altic-dev/FluidVoice)
- **Menu bar management:** Barbee (App Store)
