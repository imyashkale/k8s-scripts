#!/bin/bash

# Path to the .bashrc file
BASHRC="$HOME/.bashrc"

# Function to add an alias if it does not exist
add_alias_if_not_exists() {
    local alias_to_add=$1
    if ! grep -Fxq "$alias_to_add" $BASHRC; then
        echo "$alias_to_add" >> $BASHRC
        echo "Added: $alias_to_add"
    else
        echo "Already exists: $alias_to_add"
    fi
}

# Add aliases if they do not exist
add_alias_if_not_exists "alias k='kubectl'"
add_alias_if_not_exists "alias kk='k delete --grace-period=0 --force'"
add_alias_if_not_exists "alias kd='k --dry-run=client -o yaml'"
add_alias_if_not_exists "alias ka='k apply -f'"
add_alias_if_not_exists "alias ns='k config set-context --current --namespace'"

# Reload .bashrc
source $BASHRC
