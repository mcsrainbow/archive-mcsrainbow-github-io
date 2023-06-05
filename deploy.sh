#!/bin/bash

if [[ $(git status -s) ]]; then
  echo "The working directory is dirty, please commit all pending changes."
  exit 1;
fi

tput_green=$(tput setaf 2)
tput_reset=$(tput sgr0)

echo -e "${tput_green}0.Deploying updates to GitHub...${tput_reset}"

echo -e "${tput_green}1.Deleting old public folder...${tput_reset}"
rm -rf public
mkdir public
git worktree prune
rm -rf .git/worktrees/public/

echo -e "${tput_green}2.Checking out main branch into public...${tput_reset}"
git worktree add -B main public origin/main

echo -e "${tput_green}3.Removing existing files in public folder...${tput_reset}"
rm -rf public/*

echo -e "${tput_green}4.Generating blog...${tput_reset}"
hugo

echo -e "${tput_green}5.Updating main branch...${tput_reset}"
cd public && git add --all 

msg="Rebuild blog on $(date '+%b %d, %Y')"
if [ $# -eq 1 ]; then
  msg="$1"
fi
git commit -m "$msg"

git push -f origin main

cd ..

echo -e "${tput_green}6.Done${tput_reset}"
