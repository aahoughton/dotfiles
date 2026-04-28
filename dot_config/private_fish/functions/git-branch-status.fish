function git-branch-status
    # Per-branch status vs. origin: in sync / ahead / behind / diverged,
    # or — if the upstream is gone — try to find the squash-merge commit
    # on `main` via patch-id and surface the PR number.

    argparse 'n/depth=' 'a/all' 'no-fetch' 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: git-branch-status [-n N | --depth N] [-a | --all] [--no-fetch]"
        echo "  -n N        Scan the last N commits on main for squash-merge matches (default 500)"
        echo "  -a          Scan all of main (use on repos with deep history)"
        echo "  --no-fetch  Skip the pre-fetch of origin/main (use when offline)"
        return 0
    end

    set -l depth 500
    set -q _flag_depth; and set depth $_flag_depth
    set -q _flag_all; and set depth 0

    set -l main_branch main
    set -l current (git rev-parse --abbrev-ref HEAD)

    set -l remote_url (git remote get-url origin 2>/dev/null)
    set -l repo_https ''
    if test -n "$remote_url"
        set repo_https (string replace -r '^git@github\.com:' 'https://github.com/' -- $remote_url \
                      | string replace -r '\.git$' '')
    end

    # Refresh just origin/<main_branch> so squash-merge / ancestry checks reflect
    # the current upstream state. Non-destructive: only writes the remote-tracking ref.
    if not set -q _flag_no_fetch; and test -n "$remote_url"
        git fetch --quiet origin $main_branch 2>/dev/null
    end

    # Prefer origin/<main> for comparisons (kept current by the fetch above);
    # fall back to local main when there's no remote-tracking ref.
    set -l main_ref $main_branch
    if git show-ref --verify --quiet "refs/remotes/origin/$main_branch"
        set main_ref "origin/$main_branch"
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

    # Lazily computed: committer timestamp of the oldest commit in the scan window.
    # Used to skip patch-id work for branches whose tip predates the window — a
    # squash for those would lie outside our coverage anyway.
    set -l oldest_ts_loaded 0
    set -l oldest_ts ''

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
            # Fast path: if the branch tip is already on main, the PR was integrated
            # via a real merge commit (or fast-forward), not a squash. Find the
            # merge commit on main whose second parent is this branch tip.
            if git merge-base --is-ancestor $branch $main_ref 2>/dev/null
                set -l branch_full (git rev-parse $branch)
                set -l merge_commit ''
                for line in (git log --merges --first-parent "$branch_full..$main_ref" --pretty='%H %P' 2>/dev/null)
                    set -l parts (string split ' ' -- $line)
                    for p in $parts[2..-1]
                        if test "$p" = "$branch_full"
                            set merge_commit $parts[1]
                            break
                        end
                    end
                    test -n "$merge_commit"; and break
                end

                if test -n "$merge_commit"
                    set -l subject (git log -1 --format=%s $merge_commit)
                    set -l pr_num (string match -r '#(\d+)' -- $subject)[2]
                    set -l short_sha (string sub -l 7 $merge_commit)
                    if test -n "$pr_num"; and test -n "$repo_https"
                        printf '%s%-28s %s  merged in #%s — %s/pull/%s\n' $marker $branch $sha $pr_num $repo_https $pr_num
                    else if test -n "$pr_num"
                        printf '%s%-28s %s  merged in #%s (%s)\n' $marker $branch $sha $pr_num $short_sha
                    else
                        printf '%s%-28s %s  merged via %s\n' $marker $branch $sha $short_sha
                    end
                else
                    printf '%s%-28s %s  merged into %s (fast-forward)\n' $marker $branch $sha $main_branch
                end
                continue
            end

            # If the branch tip predates the oldest commit in the scan window, a
            # squash (if any) is outside our coverage — skip the per-branch
            # patch-id work and hint to widen the scan.
            if test $depth -gt 0
                if test $oldest_ts_loaded -eq 0
                    set oldest_ts (git log $main_ref --format=%ct -n $depth 2>/dev/null | tail -n 1)
                    set oldest_ts_loaded 1
                end
                if test -n "$oldest_ts"
                    set -l branch_ts (git log -1 --format=%ct $branch 2>/dev/null)
                    if test -n "$branch_ts"; and test "$branch_ts" -lt "$oldest_ts"
                        printf '%s%-28s %s  upstream gone, branch predates scan window (try -a or larger -n)\n' $marker $branch $sha
                        continue
                    end
                end
            end

            if test $main_pids_loaded -eq 0
                set -l log_args $main_ref -p
                test $depth -gt 0; and set -a log_args -n $depth
                set main_pids (git log $log_args 2>/dev/null | git patch-id 2>/dev/null)
                set main_pids_loaded 1
            end

            set -l branch_pid (git diff $main_ref...$branch | git patch-id | string split ' ')[1]
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
                set -l scope_note "searched last $depth commits"
                test $depth -eq 0; and set scope_note "searched all of $main_branch"
                printf '%s%-28s %s  upstream gone, no patch-id match (%s)\n' $marker $branch $sha $scope_note
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
