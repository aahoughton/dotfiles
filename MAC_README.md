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

"Server" means the machine named in `.chezmoidata/server.yaml` (behemoth
today); chezmoi installs the server-only files there and nowhere else, from
pass 2 on (pass 1 runs before the machine has its name).

1. Disable Apple's built-in password manager: System Settings > Passwords > Password Options > uncheck "Autofill Passwords and Passkeys"
2. Use Quad9 DNS (System Settings > Network > Wi-Fi > <SSID> > Details)
3. Go through each installed cask and finalize setup
   - Hyperkey: hold Caps Lock for hyper. Hyper only needs to be
     cmd+opt+shift, for Safari's profile switches (cmd-opt-shift-0 and -1).
     Hyperkey stores the modifiers as an NSEvent flag mask in `hyperFlags`
     (1835008, or 0x1C0000, is cmd+opt+ctrl). With Hyperkey quit, set
     cmd+opt+shift (0x1A0000), then reopen it:
     ```
     defaults write com.knollsoft.Hyperkey hyperFlags -int 1703936
     ```
4. LaunchBar: hide dock icon
5. Backblaze: install manually (cask doesn't work) and exclude OrbStack data directory
6. **Desktop only:** Tailscale. The desktop gets the `tailscale` formula
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
       --operator=$USER --hostname=<machine name>
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
7. **Server only:** Start OrbStack and turn on start at login
   (`orb config set app.start_at_login true`; it defaults to off, and the
   containers only come back when OrbStack does). Then run
   `~/.local/share/chezmoi/scripts/setup-atuin-server.sh` to start the atuin
   sync server, and follow the account steps it prints.
   - The server's data lives only in OrbStack's `atuin-db` volume, so after a
     wipe it starts with no accounts. Every client already has the right
     encryption key (chezmoi installs it from 1Password item `atuin-key`), so
     register once, with the username and password in item `atuin-account`,
     and the other machines' history uploads unchanged.
   - Then, on each other machine: `atuin logout`, `atuin login -u <username>`
     (password from `atuin-account`), `atuin sync`. Their old session points at
     an account that no longer exists.
   - Any machine: history recorded before pass 2 was encrypted with a key atuin
     generated itself, which pass 2 replaces, so those records can no longer be
     decrypted. `atuin store purge` deletes them.
8. **Server only:** Local LLM. `~/.config/llama/`, pi's model config in
   `~/.pi/agent/`, the API key (from 1Password item `llama-api-key`) and the
   `local.llama-agent` LaunchAgent arrive with pass 2. The weights do not.
   - Restore the weights (~56 GB, archive first, falling back to Hugging Face,
     SHA-256 verified against `models.lock.yaml`): `~/.config/llama/restore-models.sh`
   - The LaunchAgent runs `llama-agent.sh` (the server plus the step 9 tools)
     at login and restarts it if it exits. Until the weights and SearXNG are
     in place it fails and retries every 30s. An apply that changes the
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
9. **Server only:** Web search for the local model, via `llama-agent.sh`.
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

## Moving the server

To make another desktop the server, set it up as an ordinary desktop first,
then:

1. Change `server` in `.chezmoidata/server.yaml`, commit, and `chezmoi update`
   on every machine. Clients now point atuin and ssh at the new name. On the
   new server, apply lands the server-only files; on the old one they stay
   until removed by hand.
2. Run steps 7, 8 and 9 on the new server. Before registering atuin, move the
   old server's data instead: `pg_dump` from the old `atuin-db` container and
   `pg_restore` into the new one.
3. Retire the old server's `tailscale serve` and LaunchAgent.

Alternatively, retire the old machine first and give the new one the old name
(set up with the same machine name). `server.yaml` then does not change, and
step 1 is just `chezmoi update`. Each client's `~/.ssh/known_hosts` still holds
the old machine's host key under that name (`HostKeyAlias`); remove it with
`ssh-keygen -R <name>`.
