# ~/.config/fish/conf.d/op_ssh.fish

# In an ssh session, op's app integration sends its approval prompt to the
# desktop's screen, not to whoever is typing. Turn it off so op uses the
# standalone CLI account and asks for the master password in this terminal
# (README.md, "Over ssh"). In tmux this follows the pane, not the person: tmux
# copies SSH_CONNECTION into windows opened after an ssh attach, panes opened
# at the desk keep using the app, and each keeps its setting afterwards.
if set -q SSH_CONNECTION
    set -gx OP_BIOMETRIC_UNLOCK_ENABLED false
end
