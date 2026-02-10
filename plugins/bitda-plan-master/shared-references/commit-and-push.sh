#!/bin/bash
claude -p "Review staged changes with 'git diff --cached', write a conventional commit message in Korean following our project conventions, commit, and push to the current branch. Report the commit hash and push status." \
  --allowedTools "Bash,Read" \
  --max-turns 10
