# ~/.config/fish/conf.d/ghostty_tint.fish

# Tint the Ghostty tab background to say which machine this shell is talking to.
#
# Ghostty has no per-tab colour setting, and `set_tab_title` is a keybind action
# with no escape-sequence equivalent, so the only per-surface signal a shell can
# emit is OSC 11 (set background). With macos-titlebar-style = transparent that
# repaints the titlebar too, which is most of what you actually see.
#
# Tinting rather than marking the tab title is the whole point: a remote shell
# rewrites the title on every prompt, so a marker would not survive behemoth's
# first prompt. Nothing on the far end ever emits OSC 11, so the tint holds for
# the entire session with no configuration on the remote machine.
#
# Inside tmux there is no tint at all: tmux consumes OSC 11 for its own
# background rather than forwarding it, so the guard below stays quiet instead
# of emitting sequences that go nowhere.
#
# --- why the parsing is deliberately dumb ---------------------------------
#
# The failure directions are not equal:
#   - painting a host's colour while NOT on that host is a lie
#   - leaving the tab painted as this machine while on a remote one is the
#     exact mistake the tint exists to prevent
#   - painting base ("cannot tell") is honest and costs nothing
#
# Earlier versions tried to find ssh anywhere in a command line -- after a
# separator, behind a wrapper, past quoted spans. Three rounds of review found
# a leak each time, ending with a quoted argument that could paint a specific
# remote host's colour during a plain local `echo`. Matching an unparsed shell
# string has no clean bottom, so this only recognises the shape actually typed:
#
#   ssh <options> <destination>          optionally prefixed by `command`,
#                                        and the ssh may be a path
#
# Anything else that so much as mentions ssh paints base. That is noisier --
# `grep ssh /etc/services` flashes base until the next prompt -- but it makes
# the dangerous outcome structurally unreachable: the only way to get a host's
# colour is for that host to be the destination of a literal ssh command.
#
# Known limits, all of which land on base rather than a wrong host: a quoted
# option value containing spaces (`ssh -o 'ProxyCommand nc %h %p' behemoth`)
# tokenises into pieces and hides the destination; and an ssh behind a wrapper,
# after a separator, or inside a loop is not recognised at all.

# --- colour table ---------------------------------------------------------
# Retuning is a one-line edit. `colorcheck` renders these side by side, and
# takes extra candidates as arguments.

# Must match the `background` of the Ghostty theme (currently Monokai Pro
# Octagon). Used for ssh destinations we have no colour for, so that an
# unfamiliar or unreadable host is visibly *not* one of the known machines.
set -g __ghostty_tint_base '#282a3a'

# This machine, and so also the colour restored when ssh exits.
set -g __ghostty_tint_local '#203044'

function __ghostty_tint_colour -a hex -d 'Print the canonical #rrggbb form of a colour, or nothing'
    # The `#` is optional on input and mandatory on output: OSC 11 wants an X
    # colour spec, and a bare 38341a is silently ignored by the terminal --
    # which looks exactly like the tint not working.
    string match -qr -- '^#?[0-9A-Fa-f]{6}$' "$hex"; or return 1
    echo '#'(string replace -- '#' '' $hex)
end

function __ghostty_tint_canon -a name -d 'Canonical map key for a host name'
    # Registration and lookup MUST agree, so both go through here -- an earlier
    # split where only lookup stripped `.local` left `__ghostty_tint_add
    # box.local` registered but permanently unreachable.
    set -l h (string trim --chars="'\"" -- $name)
    # A separator glued to the destination (`ssh behemoth; echo x`) is not part
    # of the name. Cut at the first one rather than trimming the end, so
    # `behemoth;ssh sureify` still resolves to behemoth.
    set h (string replace -r -- '[;&|].*$' '' $h)
    set h (string replace -r -- '^.*@' '' $h)
    set h (string replace -r -- '\.(local|tailnet)$' '' $h)
    # ssh host matching is effectively case-insensitive; variable names cannot
    # hold anything outside [a-z0-9_].
    string replace -ra -- '[^a-z0-9_]' '_' (string lower -- $h)
end

function __ghostty_tint_add -a alias hex -d 'Register a background tint for an ssh destination'
    if test -z "$alias" -o -z "$hex"
        echo "__ghostty_tint_add: need both a host alias and a #rrggbb colour" >&2
        return 1
    end
    set -l colour (__ghostty_tint_colour $hex)
    if test -z "$colour"
        echo "__ghostty_tint_add: $alias: \"$hex\" is not a #rrggbb colour" >&2
        return 1
    end
    set -l key (__ghostty_tint_canon $alias)
    if test -z "$key"
        echo "__ghostty_tint_add: \"$alias\" has no usable host name in it" >&2
        return 1
    end
    # fish has no associative arrays, so the map is dynamically-named globals.
    set -l var __ghostty_tint_host_$key
    # Canonicalisation is many-to-one: a.b, a-b and A_B all key to a_b. Letting
    # the last registration win would paint one machine's colour for another,
    # so say so and keep the first. A set-but-empty variable is not a
    # registration, so it does not count as a collision.
    if set -q $var; and test -n "$$var"; and test "$$var" != "$colour"
        echo "__ghostty_tint_add: $alias collides with an earlier host on key '$key'; keeping $$var" >&2
        return 1
    end
    set -g $var $colour
end

__ghostty_tint_add behemoth '#38341a'

# Work hosts are registered in ghostty_tint.local.fish, which is deliberately
# not managed by chezmoi: this repo is public, and host entries stay out of it
# the same way ~/.ssh/config.local keeps them out of the ssh config. conf.d is
# sourced alphabetically, so that file lands after this one and finds the
# helper above already defined.

# --- lookup ---------------------------------------------------------------

function __ghostty_tint_lookup -a dest -d 'Print the tint registered for an ssh destination'
    test -n "$dest"; or return 1
    set -l key (__ghostty_tint_canon $dest)
    test -n "$key"; or return 1
    set -l var __ghostty_tint_host_$key
    set -q $var; or return 1
    test -n "$$var"; or return 1
    echo $$var
end

function __ghostty_tint_for_command -a cmdline -d 'Print the tint an ssh command line calls for'
    # ssh(1) options that consume an argument.
    set -l takes_arg B b c D E e F I i J L l m O o P p Q R S W w

    set -l tokens (string split -n ' ' -- $cmdline)
    set -q tokens[1]; or return 1

    set -l i 1
    test "$tokens[$i]" = command; and set i (math $i + 1)

    # Matches ssh and /usr/bin/ssh; not myssh, sshpass, ssh_config.
    if not string match -qr -- '(^|/)ssh$' "$tokens[$i]"
        # Not a shape we read. If the bare word appears anywhere -- behind a
        # wrapper, after a separator, inside a loop -- say "cannot tell"
        # rather than leaving the tab asserting this machine.
        if string match -qr -- '(^|[^A-Za-z0-9_])ssh([^A-Za-z0-9_]|$)' -- $cmdline
            echo $__ghostty_tint_base
            return 0
        end
        return 1
    end
    set i (math $i + 1)

    while test $i -le (count $tokens)
        set -l tok $tokens[$i]
        if string match -q -- '-*' $tok
            # Scan the bundle left to right. The first letter that takes an
            # argument consumes the rest of the token if there is one, and
            # otherwise the following token. So -oFoo=bar and -i~/key consume
            # nothing further, while -o Foo=bar and -p 2222 consume one token.
            # Taking only the last character got this backwards, and
            # -oStrictHostKeyChecking=no silently ate the destination.
            set -l letters (string split '' -- (string sub -s 2 -- $tok))
            set -l n (count $letters)
            if test $n -gt 0
                for j in (seq $n)
                    if contains -- $letters[$j] $takes_arg
                        test $j -eq $n; and set i (math $i + 1)
                        break
                    end
                end
            end
        else
            # First non-flag token is the destination. Anything after it is a
            # remote command, so stop either way -- this is what keeps
            # `ssh behemoth 'grep sureify ...'` from matching the wrong host.
            set -l hex (__ghostty_tint_lookup $tok)
            if test -n "$hex"
                echo $hex
            else
                echo $__ghostty_tint_base
            end
            return 0
        end
        set i (math $i + 1)
    end

    # An ssh whose destination we could not find.
    echo $__ghostty_tint_base
    return 0
end

# --- painting -------------------------------------------------------------

if status is-interactive
    and test "$TERM_PROGRAM" = ghostty
    and not set -q SSH_CONNECTION
    and not set -q TMUX

    function __ghostty_tint_paint -a hex -d 'Set the surface background'
        # Unconditional on purpose. Caching the last colour we sent saved a
        # 20-byte write per prompt and cost correctness: anything else that
        # sets the background -- including the printf used to audition a new
        # tint -- left the cache describing a state that no longer existed,
        # and the tab never returned to its own colour.
        printf '\e]11;%s\a' $hex
    end

    function __ghostty_tint_preexec --on-event fish_preexec -d 'Tint the tab for an ssh destination'
        set -l hex (__ghostty_tint_for_command $argv[1])
        test -n "$hex"; and __ghostty_tint_paint $hex
    end

    function __ghostty_tint_postexec --on-event fish_postexec -d 'Restore this machine tint'
        __ghostty_tint_paint $__ghostty_tint_local
    end

    # Every new tab starts in this machine's colour.
    __ghostty_tint_paint $__ghostty_tint_local
end
