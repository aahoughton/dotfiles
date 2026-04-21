# ~/.config/fish/conf.d/ssh_agent.fish

# 1. Define a persistent socket path
set -gx SSH_AUTH_SOCK "$HOME/.ssh/ssh_auth_sock"

# 2. If the socket doesn't exist, start the agent
if not test -S $SSH_AUTH_SOCK
    # Start agent and bind it to our static path
    # We use 'sed' to strip out the setenv commands and just run them
    ssh-agent -c -a $SSH_AUTH_SOCK | sed 's/^setenv/set -gx/; s/;/ /g' | source >/dev/null
end

# 3. If the agent is running but empty, load the macOS Keychain
if ssh-add -l 2>&1 | grep -q "The agent has no identities"
    # This specifically pulls keys you've previously added with --apple-use-keychain
    ssh-add --apple-load-keychain >/dev/null 2>&1
end
