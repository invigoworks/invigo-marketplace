# Review Plan Skill

When invoked, spawn 3 Task agents in parallel:
1. **Logic Reviewer**: Check planning doc for logical completeness, missing error handling, edge cases
2. **UX Reviewer**: Compare against existing app patterns, check consistency with liquor/manufacturing apps
3. **Component Reuse Reviewer**: Identify reusable components from existing codebase, flag unnecessary new components

Synthesize all findings into a single report with Critical/Major/Minor severity levels.
After review, ask user if they want to auto-apply fixes.
