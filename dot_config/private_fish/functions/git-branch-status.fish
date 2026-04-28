function git-branch-status
    # Per-branch status vs. origin: in sync / ahead / behind / diverged,
    # or — if the upstream is gone — try to find the squash-merge commit
    # on `main` via patch-id and surface the PR number.

    set -l main_branch main
    set -l current (git rev-parse --abbrev-ref HEAD)

    set -l remote_url (git remote get-url origin 2>/dev/null)
    set -l repo_https ''
    if test -n "$remote_url"
        set repo_https (string replace -r '^git@github\.com:' 'https://github.com/' -- $remote_url \
                      | string replace -r '\.git$' '')
    end

    # Source of truth for which upstream branches still exist on the remote.
    # Avoids relying on possibly-stale refs/remotes/origin/* (which only get
    # pruned when the user runs `git fetch --prune` or `git remote prune`).
    set -l live_remotes (git ls-remote --heads origin 2>/dev/null \
                         | string replace -r '.*\trefs/heads/' 'origin/')
    set -l have_live_remotes 0
    test (count $live_remotes) -gt 0; and set have_live_remotes 1

    # Lazily computed: "<patch-id> <commit-sha>" lines for the last N commits on main.
    set -l main_pids_loaded 0
    set -l main_pids

    for branch in (git for-each-ref --format='%(refname:short)' refs/heads/)
        set -l sha (git rev-parse --short $branch)
        set -l marker '  '
        test "$branch" = "$current"; and set marker '* '

        set -l upstream (git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null)

        if test -z "$upstream"
            printf '%s%-28s %s  no upstream\n' $marker $branch $sha
            continue
        end

        set -l is_gone 0
        if test $have_live_remotes -eq 1
            contains -- $upstream $live_remotes; or set is_gone 1
        else
            git show-ref --verify --quiet "refs/remotes/$upstream"; or set is_gone 1
        end

        if test $is_gone -eq 1
            if test $main_pids_loaded -eq 0
                set main_pids (git log $main_branch -p -n 500 2>/dev/null | git patch-id 2>/dev/null)
                set main_pids_loaded 1
            end

            set -l branch_pid (git diff $main_branch...$branch | git patch-id | string split ' ')[1]
            set -l matched_sha ''
            if test -n "$branch_pid"
                for line in $main_pids
                    set -l parts (string split ' ' -- $line)
                    if test "$parts[1]" = "$branch_pid"
                        set matched_sha $parts[2]
                        break
                    end
                end
            end

            if test -n "$matched_sha"
                set -l subject (git log -1 --format=%s $matched_sha)
                set -l pr_num (string match -r '#(\d+)' -- $subject)[2]
                set -l short_sha (string sub -l 7 $matched_sha)
                if test -n "$pr_num"; and test -n "$repo_https"
                    printf '%s%-28s %s  merged in #%s — %s/pull/%s\n' $marker $branch $sha $pr_num $repo_https $pr_num
                else if test -n "$pr_num"
                    printf '%s%-28s %s  merged in #%s (%s)\n' $marker $branch $sha $pr_num $short_sha
                else
                    printf '%s%-28s %s  merged as %s\n' $marker $branch $sha $short_sha
                end
            else
                printf '%s%-28s %s  upstream gone, no patch-id match on %s\n' $marker $branch $sha $main_branch
            end
            continue
        end

        set -l counts (git rev-list --left-right --count "$upstream...$branch" | string split \t)
        set -l behind $counts[1]
        set -l ahead $counts[2]
        if test "$ahead" = 0; and test "$behind" = 0
            printf '%s%-28s %s  in sync with %s\n' $marker $branch $sha $upstream
        else if test "$behind" = 0
            printf '%s%-28s %s  ahead %s of %s\n' $marker $branch $sha $ahead $upstream
        else if test "$ahead" = 0
            printf '%s%-28s %s  behind %s of %s\n' $marker $branch $sha $behind $upstream
        else
            printf '%s%-28s %s  diverged: %s ahead, %s behind %s\n' $marker $branch $sha $ahead $behind $upstream
        end
    end
end
