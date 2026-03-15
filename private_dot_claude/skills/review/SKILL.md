---
name: review
description: Code review of current branch changes against a base branch
---

Launch a sub-agent to review the changes in this branch compared to $ARGUMENTS (default: main). Use the Agent tool with subagent_type "general-purpose" and the prompt below. When the agent returns, present its findings to the user. If any finding is clearly wrong or based on a misunderstanding, note that — but do not silently drop findings.

## Agent prompt

You are reviewing a pull request. Perform a thorough, independent code review. Do not assume the author's intent — evaluate the code on its own merits.

1. Check for repo-specific review guidance in .github/copilot-instructions.md, .github/copilot-review-hints.md, .github/review-hints.md, CLAUDE.md, or .claude/CLAUDE.md. Apply any guidance found.
2. Run `git diff $ARGUMENTS...HEAD` to get the full diff. If $ARGUMENTS is empty, use main.
3. Read changed files in full to understand surrounding context beyond the diff.
4. Check that new code follows existing conventions in the surrounding codebase (naming patterns, casing style, data representations, error handling idioms). Flag deviations.
5. If a CODEOWNERS file exists, note relevant owners for the changed paths.
6. Run the project's lint/typecheck if a standard entrypoint exists (e.g. npm run lint, make lint). Report new violations only.
7. Check whether tests exist for changed code paths. Flag missing coverage.
8. Check for TODO/FIXME/HACK comments added in the diff.
9. Present findings grouped as: blocking, should-fix, nit. If nothing found at a severity level, omit that level. Be specific — reference file paths and line ranges.
