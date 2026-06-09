function asp --description 'Set AWS Profile and login via SSO'
    if contains -- -h $argv; or contains -- --help $argv
        echo "Usage: asp [profile_name] [--use-device-code]"
        echo
        echo "  asp                                Show current profile + SSO session lifetime, list profiles."
        echo "  asp <profile> [--use-device-code]  Switch to <profile>, logging in via SSO if the session expired."
        echo "                                     --use-device-code uses the device-code auth flow."
        echo "  asp -h, --help                     Show this help."
        return 0
    end

    # No arguments at all: show current profile + SSO session lifetime, then list profiles
    if test (count $argv) -eq 0
        if test -n "$AWS_PROFILE"
            echo "Current profile: $AWS_PROFILE"
            set -l exp (__asp_session_expiry_epoch $AWS_PROFILE)
            if test -n "$exp"
                set -l secs (math "$exp - "(date +%s))
                if test "$secs" -gt 0
                    echo "SSO session valid for "(__asp_format_remaining $secs)
                else
                    echo "SSO session expired (run: asp $AWS_PROFILE)"
                end
            else
                echo "SSO session: unknown (run: asp $AWS_PROFILE)"
            end
            echo
        end
        for p in (aws configure list-profiles | sort)
            if test "$p" = "$AWS_PROFILE"
                echo "* $p"
            else
                echo "  $p"
            end
        end
        return 0
    end

    set -l profile ""
    set -l login_args

    for arg in $argv
        switch $arg
            case --use-device-code
                set -a login_args $arg
            case '*'
                set profile $arg
        end
    end

    if test -z "$profile"
        echo "Error: a profile name is required (e.g. asp <profile> --use-device-code)." >&2
        return 1
    end

    if not aws configure list-profiles | string match -qr "^$profile\$"
        echo "Error: Profile '$profile' not found in ~/.aws/config" >&2
        return 1
    end

    set -l old_profile $AWS_PROFILE
    set -gx AWS_PROFILE $profile

    # Skip login while the SSO session is still alive
    set -l exp (__asp_session_expiry_epoch $profile)
    if test -n "$exp"; and test "$exp" -gt (date +%s)
        echo "AWS_PROFILE set to $profile (SSO session valid for "(__asp_format_remaining (math "$exp - "(date +%s)))")"
        return 0
    end

    echo "SSO session expired, logging in..."
    if aws sso login $login_args
        echo "AWS_PROFILE set to $profile"
    else
        set -l login_status $status
        echo "Error: SSO login failed (exit code: $login_status)." >&2
        if test -n "$old_profile"
            set -gx AWS_PROFILE $old_profile
            echo "Rolling back to previous profile: $old_profile" >&2
        else
            set -e AWS_PROFILE
            echo "Unsetting AWS_PROFILE." >&2
        end
        return 1
    end
end

# Locate the cached SSO token file backing a profile's session.
# Modern config keys the cache on the sso_session name; legacy on sso_start_url.
# The cache filename is sha1(key).json. Falls back to a lone cached token.
function __asp_sso_token_file --argument-names profile
    set -l key
    set -l start_url (aws configure get sso_start_url --profile $profile 2>/dev/null)
    if test -n "$start_url"
        set key (printf '%s' $start_url | shasum -a 1 | string split -f1 ' ')
    else
        set -l sess (aws configure get sso_session --profile $profile 2>/dev/null)
        if test -n "$sess"
            set key (printf '%s' $sess | shasum -a 1 | string split -f1 ' ')
        end
    end

    if test -n "$key"; and test -f ~/.aws/sso/cache/$key.json
        echo ~/.aws/sso/cache/$key.json
        return 0
    end

    # Fallback: if exactly one SSO token is cached, use it.
    set -l files (grep -l accessToken ~/.aws/sso/cache/*.json 2>/dev/null)
    if test (count $files) -eq 1
        echo $files[1]
        return 0
    end
    return 1
end

# Echo the epoch at which a profile's SSO session expires (nothing if unknown).
function __asp_session_expiry_epoch --argument-names profile
    set -l f (__asp_sso_token_file $profile)
    test -n "$f"; or return 1
    set -l expiry (cat $f | string match -rg '"expiresAt"\s*:\s*"([^"]+)"')
    test -n "$expiry"; or return 1
    # ISO8601 -> epoch; BSD date needs +0000, not Z / UTC / +00:00
    set -l norm (string replace -r 'Z$' '+0000' -- $expiry \
        | string replace -r 'UTC$' '+0000' \
        | string replace -r '([+-]\d{2}):(\d{2})$' '$1$2')
    date -j -f "%Y-%m-%dT%H:%M:%S%z" $norm +%s 2>/dev/null
end

# Format a duration in seconds as "Xh Ym".
function __asp_format_remaining --argument-names secs
    set -l mins (math --scale=0 "floor($secs / 60)")
    echo (math --scale=0 "floor($mins / 60)")"h "(math "$mins % 60")"m"
end
