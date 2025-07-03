#!/bin/bash

## PURPOSE:  compare commits
## Please add and commit before running


# not yet added
c=$(git diff --cached HEAD)
echo "cached, not yet commited ...$c"

# files untracked?
u=$(git diff --name-only HEAD~1)
echo "untracked files...$u"

# compare parent commit to latest:  1 means changes
git diff --exit-code --quiet HEAD~ HEAD  
echo $?
