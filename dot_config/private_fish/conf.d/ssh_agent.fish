# ~/.config/fish/conf.d/ssh_agent.fish

# 1. Define a persistent socket path
set -gx SSH_AUTH_SOCK "$HOME/.ssh/ssh_auth_sock"

# 2. Start the agent unless one is actually reachable.
# Testing for the socket file is not enough: a dead agent leaves its socket
# behind, so `test -S` keeps succeeding while every connection is refused, and
# the agent is never restarted. Probe the agent instead — ssh-add -l exits 2
# when it can't be reached (0 = has keys, 1 = reachable but empty). The stale
# socket has to go first, or ssh-agent -a refuses to bind to that path.
ssh-add -l >/dev/null 2>&1
if test $status -eq 2
    rm -f $SSH_AUTH_SOCK
    # Start agent and bind it to our static path
    # We use 'sed' to strip out the setenv commands and just run them
    ssh-agent -c -a $SSH_AUTH_SOCK | sed 's/^setenv/set -gx/; s/;/ /g' | source >/dev/null
end

# 3. If the agent is running but empty, load the macOS Keychain
if ssh-add -l 2>&1 | grep -q "The agent has no identities"
    # This specifically pulls keys you've previously added with --apple-use-keychain
    ssh-add --apple-load-keychain >/dev/null 2>&1
end
