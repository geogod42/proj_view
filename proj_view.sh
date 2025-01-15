#!/bin/bash

# proj_view.sh
#
# This script generates a textual overview of the project's directory structure
# and outputs it to proj_structure.txt.
# It respects ignore patterns defined in .overviewignore, which it will create
# if it doesn't already exist. The user is given the option to add additional
# patterns at that time.
#
# Usage:
#   ./proj_view.sh
#
# The resulting structure is printed to STDOUT and saved in proj_structure.txt.
#
# ------------------------------------------------------------------------------

# Set the root directory to the current working directory
root_dir="$(pwd)"

# Define the name of the output file
output_filename="proj_structure.txt"

# Initialize an array to hold ignore patterns, starting with .overviewignore itself
patterns=(".overviewignore")

# ------------------------------------------------------------------------------
# Function: load_overviewignore
# Reads ignore patterns from .overviewignore into the `patterns` array.
# Skips empty lines and comment lines (starting with '#').
# ------------------------------------------------------------------------------
load_overviewignore() {
    local overviewignore_path="$root_dir/.overviewignore"
    if [[ -f "$overviewignore_path" ]]; then
        while IFS= read -r line; do
            # Remove leading/trailing whitespace
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            # Skip empty lines and comments
            if [[ -n "$line" && ! "$line" =~ ^# ]]; then
                patterns+=("$line")
            fi
        done < "$overviewignore_path"
    fi
}

# ------------------------------------------------------------------------------
# Function: is_ignored
# Checks if the given path should be ignored based on patterns in the `patterns` array.
# Returns 0 (true) if the entry is to be ignored, or 1 (false) otherwise.
# ------------------------------------------------------------------------------
is_ignored() {
    local entry="$1"
    for pattern in "${patterns[@]}"; do
        # Check for exact match or if it's a subdirectory/file within the pattern
        if [[ "$entry" == "$pattern" || "$entry" == "$pattern/"* ]]; then
            return 0  # This entry is ignored
        fi
    done
    return 1  # This entry is not ignored
}

# ------------------------------------------------------------------------------
# Function: list_directory
# Recursively lists directory contents (files first, then subdirectories),
# while respecting ignore patterns.
# Parameters:
#   $1 - Path to the directory to list
#   $2 - Indentation string for visual hierarchy in the output
# ------------------------------------------------------------------------------
list_directory() {
    local path="$1"
    local indent="$2"

    # Gather all entries in this directory, sorted alphabetically
    # 2>/dev/null suppresses errors (e.g., permissions issues)
    local entries=($(ls -A "$path" 2>/dev/null | sort))

    # First, list all files in this directory
    for entry in "${entries[@]}"; do
        local entry_path="$path/$entry"
        local rel_path="${entry_path#$root_dir/}"  # relative path to the project root
        if is_ignored "$rel_path"; then
            continue
        fi
        if [[ -f "$entry_path" ]]; then
            echo "${indent}├── $entry" >> "$output_filename"
        fi
    done

    # Next, list all directories in this directory
    for entry in "${entries[@]}"; do
        local entry_path="$path/$entry"
        local rel_path="${entry_path#$root_dir/}"
        if is_ignored "$rel_path"; then
            continue
        fi
        if [[ -d "$entry_path" ]]; then
            echo "${indent}├── $entry/" >> "$output_filename"
            # Recursively descend into this subdirectory, adding to the indentation
            list_directory "$entry_path" "${indent}│   "
        fi
    done
}

# ------------------------------------------------------------------------------
# Function: create_overviewignore
# Creates a .overviewignore file with some default patterns (Git-related),
# and then optionally allows the user to add additional patterns.
# ------------------------------------------------------------------------------
create_overviewignore() {
    local overviewignore_path="$root_dir/.overviewignore"

    # Create the .overviewignore file with some default patterns
    cat > "$overviewignore_path" <<EOL
# Ignore Git folders and files
.git
.gitignore
EOL
    echo ".overviewignore has been created at $overviewignore_path with prefilled Git ignore patterns."

    # Prompt the user to add more patterns interactively
    while true; do
        read -rp "Would you like to add more patterns to .overviewignore? (y/n): " yn
        case $yn in
            [Yy]* )
                echo "Enter additional patterns to ignore (press Enter on an empty line to finish):"
                while true; do
                    read pattern
                    # If input is empty, break the loop
                    if [[ -z "$pattern" ]]; then
                        break
                    fi
                    # Append the pattern to .overviewignore
                    echo "$pattern" >> "$overviewignore_path"
                done
                break
                ;;
            [Nn]* )
                echo "No additional patterns added to .overviewignore."
                break
                ;;
            * )
                echo "Please answer y or n."
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
if [[ ! -f "$root_dir/.overviewignore" ]]; then
    # If .overviewignore doesn't exist, create it with default patterns and
    # optionally allow the user to add more.
    create_overviewignore
fi

# Load ignore patterns from the .overviewignore file
load_overviewignore

# Start building the project structure output
# Overwrite the output file if it exists, or create a new one
echo "$(basename "$root_dir")/" > "$output_filename"
echo "│" >> "$output_filename"

# Recursively generate the directory structure
list_directory "$root_dir" ""

# Display the generated structure on the console
cat "$output_filename"

