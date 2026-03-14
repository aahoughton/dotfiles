function asp --description 'Set AWS Profile and login via SSO'
    set -l profile (if test -n "$argv[1]"; echo $argv[1]; else; echo $AWS_PROFILE; end)

    if test -z "$profile"
        echo "Usage: asp <profile_name>" >&2
        echo "       (or set AWS_PROFILE first)" >&2
        return 1
    end

    if not aws configure list-profiles | string match -qr "^$profile\$"
        echo "Error: Profile '$profile' not found in ~/.aws/config" >&2
        return 1
    end

    set -l old_profile $AWS_PROFILE
    set -gx AWS_PROFILE $profile

    # Skip login if credentials are already valid
    if aws sts get-caller-identity &>/dev/null
        echo "AWS_PROFILE set to $profile (credentials valid)"
        return 0
    end

    echo "Credentials expired, logging in..."
    if aws sso login
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

