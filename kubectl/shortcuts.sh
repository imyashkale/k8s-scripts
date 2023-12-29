#!/bin/bash

# Determine the current shell and set the corresponding configuration file
if [ -n "$ZSH_VERSION" ]; then
    # Zsh is being used
    CONFIG_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    # Bash is being used
    CONFIG_FILE="$HOME/.bashrc"
else
    # Default to .bashrc if the shell is neither Bash nor Zsh
    CONFIG_FILE="$HOME/.bashrc"
    echo "Unknown shell. Defaulting to Bash settings."
fi

# Function to add an alias if it does not exist
add_alias_if_not_exists() {
    local alias_to_add=$1
    if ! grep -Fxq "$alias_to_add" "$CONFIG_FILE"; then
        echo "$alias_to_add" >> "$CONFIG_FILE"
        echo "Added: $alias_to_add"
    else
        echo "Already exists: $alias_to_add"
    fi
}

# Add aliases if they do not exist
add_alias_if_not_exists "alias k='kubectl'"
add_alias_if_not_exists "alias kk='kubectl delete --grace-period=0 --force'"
add_alias_if_not_exists "alias kd='kubectl --dry-run=client -o yaml'"
add_alias_if_not_exists "alias ka='kubectl apply -f'"
add_alias_if_not_exists "alias ns='kubectl config set-context --current --namespace'"

# Reload the configuration file
if [ -n "$ZSH_VERSION" ]; then
    source "$CONFIG_FILE"
elif [ -n "$BASH_VERSION" ]; then
    source "$CONFIG_FILE"
else
    echo "Reloading the shell configuration is not supported for the current shell."
fi
