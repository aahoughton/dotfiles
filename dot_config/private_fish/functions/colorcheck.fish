function __colorcheck_valid_hex -a hex -d 'True if the argument is a #rrggbb colour'
    string match -qr -- '^#?[0-9A-Fa-f]{6}$' "$hex"
end

function __colorcheck_rgb -a hex -d 'Convert #rrggbb to the r;g;b form SGR truecolor wants'
    set -l h (string replace -- '#' '' $hex)
    printf '%d;%d;%d' \
        (math "0x"(string sub -s 1 -l 2 -- $h)) \
        (math "0x"(string sub -s 3 -l 2 -- $h)) \
        (math "0x"(string sub -s 5 -l 2 -- $h))
end

function colorcheck -d 'Show text attributes and palette colours against the current and candidate backgrounds'
    # Attributes and palette are drawn with the terminal's own indices rather
    # than hex, so they stay honest if the theme changes. The backgrounds
    # section uses truecolor because the whole point is to audition colours
    # that are not the current background.
    #
    # Extra candidates can be passed as arguments:
    #     colorcheck '#3a2f20' '#402c1c'

    set -l names black red green yellow blue magenta cyan white

    echo
    printf '\e[1mattributes\e[0m  \e[2m(default foreground on the current background)\e[0m\n  '
    printf '\e[0mregular\e[0m   \e[1mbold\e[0m   \e[2mdim\e[0m   \e[3mitalic\e[0m   '
    printf '\e[4munderline\e[0m   \e[9mstrike\e[0m   \e[7m reverse \e[0m\n'

    echo
    printf '\e[1mpalette\e[0m  \e[2m(the active theme'"'"'s 16)\e[0m\n'
    for i in (seq 0 7)
        set -l b (math $i + 8)
        set -l n $names[(math $i + 1)]
        printf '  %2d %-8s \e[38;5;%dm██ Aa\e[0m \e[1;38;5;%dmbold\e[0m \e[2;38;5;%dmdim\e[0m' $i $n $i $i $i
        printf '    %2d %-9s \e[38;5;%dm██ Aa\e[0m \e[1;38;5;%dmbold\e[0m \e[2;38;5;%dmdim\e[0m\n' $b "br$n" $b $b $b
    end

    # Registered tints, plus anything passed on the command line. Built as
    # label:hex pairs rather than two parallel arrays, so a row that has to be
    # skipped cannot shift every later row onto the wrong colour.
    set -l labels
    set -l hexes
    # Concatenating an empty command substitution yields an empty list, which
    # would drop the label AND the colour -- and the local tint is the one
    # every candidate is judged against.
    set -l localname (hostname -s 2>/dev/null)
    test -n "$localname"; or set localname local
    set -l pairs base:$__ghostty_tint_base $localname:$__ghostty_tint_local
    for var in (set --names | string match '__ghostty_tint_host_*' | sort)
        set -l val $$var
        set -a pairs (string replace -- '__ghostty_tint_host_' '' $var):"$val[1]"
    end
    for hex in $argv
        set -a pairs candidate:$hex
    end

    for pair in $pairs
        set -l label (string split -m1 -- ':' $pair)[1]
        set -l hex (string split -m1 -- ':' $pair)[2]
        if not __colorcheck_valid_hex "$hex"
            if test -n "$hex"
                printf '  %-14s \e[2m(skipped: "%s" is not a #rrggbb colour)\e[0m\n' $label $hex >&2
            else
                printf '  %-14s \e[2m(skipped: no colour registered)\e[0m\n' $label >&2
            end
            continue
        end
        # Canonical #rrggbb, so a row typed as `3a2f20` renders and labels
        # itself the same way the tint table stores it.
        set -a labels $label
        set -a hexes '#'(string replace -- '#' '' $hex)
    end

    if test (count $hexes) -gt 0
        echo
        printf '\e[1mbackgrounds\e[0m  \e[2m(same text over each tint)\e[0m\n'
        for i in (seq (count $hexes))
            printf '  %-14s %-9s' $labels[$i] $hexes[$i]
            printf '\e[48;2;%sm' (__colorcheck_rgb $hexes[$i])
            printf '\e[38;5;15m  Aa sample \e[38;5;8m comment \e[38;5;2m string '
            printf '\e[38;5;3m keyword \e[38;5;12m ident \e[38;5;1m error  \e[0m\n'
        end
    end
    echo
end
