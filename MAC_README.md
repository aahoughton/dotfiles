# macOS Post-Setup

After running the bootstrap from [README.md](README.md), the following are handled automatically:

- Machine name (prompted during `chezmoi init`)
- Homebrew packages and casks
- Global mise tools (Node LTS and CLIs such as pi and codex)
- Default shell set to fish
- SSH / Remote Login enabled
- Dock: autohide, hide recents
- Trackpad: tap to click
- Function keys as standard function keys
- Spotlight keyboard shortcuts disabled
- Battery percentage in menu bar
- Sound in menu bar
- Desktop only: on AC power, never sleep, restart after a power failure, wake for network access (`pmset`)

## Manual Steps

1. Disable Apple's built-in password manager: System Settings > Passwords > Password Options > uncheck "Autofill Passwords and Passkeys"
2. Use Quad9 DNS (System Settings > Network > Wi-Fi > <SSID> > Details)
3. Go through each installed cask and finalize setup
4. LaunchBar: hide dock icon
5. Backblaze: install manually (cask doesn't work) and exclude OrbStack data directory
6. **Behemoth only:** Start OrbStack and turn on start at login
   (`orb config set app.start_at_login true`; it defaults to off, and the
   containers only come back when OrbStack does). Then run `~/.local/share/chezmoi/scripts/setup-atuin-server.sh` to start the atuin sync server, then follow the account steps it prints.
   - The server's data lives only in OrbStack's `atuin-db` volume, so after a
     wipe it starts with no accounts. The other machines still hold the old
     encryption key, and behemoth's client has generated a new one. Before
     registering, copy the key from another machine (`atuin key` there) and
     run `atuin store rekey '<key>'` on behemoth.
   - Then, on each other machine: `atuin logout`, `atuin login -u <username>`,
     `atuin sync`. Their old session points at an account that no longer
     exists.
7. **Behemoth only:** Tailscale. The desktop gets the `tailscale` formula
   (open-source `tailscaled`) instead of the GUI app, so it can be a Tailscale
   SSH server and come up before anyone logs in.
   - If the `tailscale-app` cask is installed, quit it, `brew uninstall --cask
     tailscale-app`, then `brew link tailscale` (the cask's CLI wrapper blocks
     the link). Remove the network extension and VPN profile it leaves behind:
     drag `/Applications/Tailscale.app` to the Trash if a stub remains, and
     delete the profile in System Settings > VPN.
   - Start the daemon as a root LaunchDaemon and join the tailnet:
     ```
     sudo brew services start tailscale
     sudo tailscale up --ssh --advertise-exit-node --accept-routes \
       --operator=$USER --hostname=behemoth
     ```
     `--operator` lets `tailscale serve` and `tailscale status` run without
     sudo. `tailscaled` writes its own `/etc/resolver` files, so MagicDNS works
     with no extra setup.
   - In the admin console: approve the exit node, disable key expiry, and make
     sure the policy's `ssh` rule uses `accept` (not `check`) for
     `autogroup:nonroot`, or keyless logins from apps will stall on a browser
     check.
   - `brew upgrade` does not restart the daemon. Run
     `sudo brew services restart tailscale` afterwards.
   - FileVault keeps the disk locked after a cold boot, so `tailscaled` starts
     only once the disk is unlocked. Use `sudo fdesetup authrestart` for
     planned reboots.
8. **Behemoth only:** Local LLM. `~/.config/llama/` and `~/.pi/` arrive with the
   first apply; the weights and the API key do not.
   - Recover the server API key. It is deliberately unmanaged, because this repo
     is public:
     ```
     op read "op://dotfiles/behemoth_llama-server/credential" \
       > ~/.config/llama/api-key && chmod 600 ~/.config/llama/api-key
     ```
   - Restore the weights (~56 GB, archive first, falling back to Hugging Face,
     SHA-256 verified against `models.lock.yaml`): `~/.config/llama/restore-models.sh`
   - Run `chezmoi apply`. Once the key exists it installs and loads the
     `local.llama-agent` LaunchAgent, which runs `llama-agent.sh` (the server
     plus the step 9 tools) at login and restarts it if it exits. Until
     SearXNG is up it fails and retries every 30s. An apply that changes the
     llama scripts, `mcp-servers.json` or `models.lock.yaml` restarts it. Log:
     `~/Library/Logs/llama-agent.log`.
   - `launchctl bootout gui/$(id -u)/local.llama-agent` stops it until the
     next login; `launchctl disable` with the same target keeps it off
     (`enable` undoes it). For the plain server with no tools, stop it and run
     `~/.config/llama/llama-serve.sh`.
   - Expose it to the tailnet. The server binds loopback, so without this only
     this machine can reach it. Persists across reboots:
     ```
     tailscale serve --bg --http=8080 http://127.0.0.1:8080
     ```
     Then it answers at `http://behemoth:8080` from any tailnet device, and
     nowhere on the LAN. Use `--https=443` instead once HTTPS certs are enabled
     for the tailnet; they are not today, and `tailscale serve --https` hangs on
     cert provisioning rather than reporting why.
9. **Behemoth only:** Web search for the local model, via `llama-agent.sh`.
   - Generate the SearXNG secret. Unmanaged for the same reason as the API key:
     ```
     printf 'SEARXNG_SECRET=%s\n' "$(openssl rand -hex 32)" \
       > ~/.config/llama/searxng.env && chmod 600 ~/.config/llama/searxng.env
     ```
   - Start SearXNG (OrbStack must be running):
     ```
     docker compose -f ~/.config/llama/searxng/compose.yaml up -d
     ```
   - The LaunchAgent from step 8 picks it up within 30s. Check it:
     `curl -s localhost:8889/healthz` should return `OK`, and
     `curl -s -H "Authorization: Bearer $(cat ~/.config/llama/api-key)"
     localhost:8080/tools | jq length` should return 4.

   Tools are reachable by anything holding the API key, and `POST /tools` runs
   them with no model involved. Treat the key as the whole boundary. `-t` adds
   llama.cpp's file and shell tools inside a throwaway container with nothing
   mounted; do not add `--tools` to `llama-serve.sh` directly, where they would
   run against your home directory.

## Optional Software

Not included in the automated install — evaluate per-machine:

- **Transcription:** [superwhisper](https://superwhisper.com), if the installed Fluid Voice falls short
- **Menu bar management:** Barbee (App Store)
