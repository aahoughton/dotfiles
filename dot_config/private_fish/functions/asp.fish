function asp --description 'Set AWS Profile and Login with error handling'
    set -l profile $argv[1]
    
    # 1. Error: No profile provided
    if test -z "$profile"
        set_color red
        echo "Error: No profile name provided."
        set_color normal
        echo "Usage: asp <profile_name>"
        return 1
    end

    # 2. Check if the profile actually exists in ~/.aws/config
    # We use 'aws configure list-profiles' to validate
    if not aws configure list-profiles | string match -qr "^$profile\$"
        set_color red
        echo "Error: Profile '$profile' not found in ~/.aws/config"
        set_color normal
        return 1
    end

    # Store the old profile in case login fails
    set -l old_profile $AWS_PROFILE

    # 3. Attempt to set the profile and login
    set -gx AWS_PROFILE $profile
    
    echo "Attempting SSO login for '$profile'..."
    if aws sso login
        set_color green
        echo "Success: Terminal identity updated to $profile"
        set_color normal
    else
        # 4. Error: Login failed (e.g., network error, expired session, or user cancel)
        set -l login_status $status
        set_color red
        echo "Error: SSO login failed (exit code: $login_status)."
        
        # Roll back to the previous profile so your prompt stays accurate
        if test -n "$old_profile"
            set -gx AWS_PROFILE $old_profile
            echo "Rolling back to previous profile: $old_profile"
        else
            set -e AWS_PROFILE
            echo "Unsetting AWS_PROFILE."
        end
        set_color normal
        return 1
    end
end

