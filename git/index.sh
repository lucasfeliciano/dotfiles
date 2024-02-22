#!/bin/bash
source ../utils/utils.sh

e_ask "Type the name you would like to display in your git commits: "
read name
if [ -z "$name" ]; then
  echo "name not supplied"
else
  git config --global user.name "$name"
fi

e_ask "Type your git email: "
read email
if [ -z "$email" ]; then
  echo "email not supplied"
else
  git config --global user.email "$email"
fi

# Set default pull strategy to rebase
git config --global pull.rebase true
