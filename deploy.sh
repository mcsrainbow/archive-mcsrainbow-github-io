#!/bin/bash

if [[ $(git status -s) ]]; then
  echo "The working directory is dirty, please commit all pending changes."
  exit 1;
fi

echo -e "\033[0;32m0.Deploying updates to GitHub...\033[0m"

echo -e "\033[0;32m1.Deleting old public folder...\033[0m"
rm -rf public
mkdir public
git worktree prune
rm -rf .git/worktrees/public/

echo -e "\033[0;32m2.Checking out main branch into public...\033[0m"
git worktree add -B main public origin/main

echo -e "\033[0;32m3.Removing existing files in public folder...\033[0m"
rm -rf public/*

echo -e "\033[0;32m4.Generating blog...\033[0m"
hugo

echo -e "\033[0;32m5.Updating main branch...\033[0m"
cd public && git add --all 

msg="Rebuild blog on $(date '+%b %d, %Y')"
if [ $# -eq 1 ]; then
  msg="$1"
fi
git commit -m "$msg"

git push -f origin main

cd ..
