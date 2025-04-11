#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Constants and help message.
OLD_NAME="template_component_package"
HELP_MESSAGE="Usage: $0 [--dry-run]
This script initializes the package by prompting you to choose which component variants to include:
  - Python Lifecycle Component
  - Python Component
  - C++ Lifecycle Component
  - C++ Component

Based on your choices, it will set up (or remove) the corresponding files and directories.

Options:
  --dry-run    Display the actions without making any changes.
  -h, --help   Show this help message."

DRY_RUN=false

# Get script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# (1) Check that the package folder is still the pristine template.
EXPECTED_FOLDER="${OLD_NAME}"
if [ ! -d "${SCRIPT_DIR}/source/${EXPECTED_FOLDER}" ]; then
  echo "ERROR: Expected package folder '${EXPECTED_FOLDER}' not found in ${SCRIPT_DIR}/source."
  echo "It appears that the package has already been modified. Aborting."
  exit 1
fi

# Process options.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      echo "${HELP_MESSAGE}"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "${HELP_MESSAGE}"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done



##############################
# Function definitions       #
##############################

log() {
  echo "$1"
}

prompt_nonempty() {
  local prompt_msg="$1"
  local input
  while true; do
    read -p $'\e[3;36m'"${prompt_msg}"$'\e[0m ' input
    if [[ -n "${input}" ]]; then
      echo "${input}"
      return
    else
      log "Input cannot be empty. Please try again."
    fi
  done
}

prompt_yesno() {
  local prompt_msg="$1"
  local ans
  while true; do
    read -p $'\e[3;36m'"${prompt_msg} [Y/n]:"$'\e[0m ' ans
    if [[ -z "$ans" ]]; then
      ans="y"
    fi
    ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
    if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
      echo "yes"
      return
    elif [[ "$ans" == "n" || "$ans" == "no" ]]; then
      echo "no"
      return
    else
      log "Invalid input. Please enter y or n. (Default is n)"
    fi
  done
}

delete_path() {
  local path="$1"
  if [ -e "${path}" ]; then
    if [[ "${DRY_RUN}" == true ]]; then
      log "Dry run: would delete ${path}"
    else
      rm -rf "${path}"
      log "Deleted ${path}"
    fi
  else
    log "Not found: ${path}"
  fi
}

# OS-agnostic in-place sed.
sed_inplace() {
  local script="$1"
  local file="$2"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$script" "$file"
  else
    sed -i "$script" "$file"
  fi
}

replace_text_in_file() {
  local file="$1"
  log "Replacing text in file: ${file}"
  if [[ "${DRY_RUN}" == true ]]; then
    return
  fi
  sed_inplace "s/${OLD_NAME}/${NEW_PACKAGE_NAME}/g" "${file}"
  local HYPHENATED_OLD="${OLD_NAME//_/-}"
  local HYPHENATED_NEW="${NEW_PACKAGE_NAME//_/-}"
  sed_inplace "s/${HYPHENATED_OLD}/${HYPHENATED_NEW}/g" "${file}"
}

rename_item() {
  local old_path="$1"
  local base
  base=$(basename "${old_path}")
  local new_base="${base//${OLD_NAME}/${NEW_PACKAGE_NAME}}"
  local new_path
  new_path="$(dirname "${old_path}")/${new_base}"
  log "Renaming: ${old_path}  -->  ${new_path}"
  if [[ "${DRY_RUN}" == false ]]; then
    mv "${old_path}" "${new_path}"
  fi
}

##############################
# Main execution flow        #
##############################

# Prompt for the new package name.
NEW_PACKAGE_NAME=$(prompt_nonempty "Enter the new component package name:")

# Ask which variants to include (defaulting to no).
INCLUDE_PYTHON_LIFECYCLE=$(prompt_yesno "Include Python Lifecycle component?")
INCLUDE_PYTHON_COMPONENT=$(prompt_yesno "Include Python Component?")
INCLUDE_CPP_LIFECYCLE=$(prompt_yesno "Include C++ Lifecycle component?")
INCLUDE_CPP_COMPONENT=$(prompt_yesno "Include C++ Component?")

# Determine if each language is included at all.
if [[ "${INCLUDE_PYTHON_LIFECYCLE}" == "yes" || "${INCLUDE_PYTHON_COMPONENT}" == "yes" ]]; then
  INCLUDE_PYTHON="yes"
else
  INCLUDE_PYTHON="no"
fi

if [[ "${INCLUDE_CPP_LIFECYCLE}" == "yes" || "${INCLUDE_CPP_COMPONENT}" == "yes" ]]; then
  INCLUDE_CPP="yes"
else
  INCLUDE_CPP="no"
fi

# Display the choices.
echo
log "New Package Name        : ${NEW_PACKAGE_NAME}"
log "Include Python?         : ${INCLUDE_PYTHON}"
if [[ "${INCLUDE_PYTHON}" == "yes" ]]; then
  log "  - Python Lifecycle    : ${INCLUDE_PYTHON_LIFECYCLE}"
  log "  - Python Component    : ${INCLUDE_PYTHON_COMPONENT}"
fi
log "Include C++?            : ${INCLUDE_CPP}"
if [[ "${INCLUDE_CPP}" == "yes" ]]; then
  log "  - C++ Lifecycle       : ${INCLUDE_CPP_LIFECYCLE}"
  log "  - C++ Component       : ${INCLUDE_CPP_COMPONENT}"
fi
echo

# Build list of files/directories to delete.
FILES_TO_DELETE=()

# --- Python-related files ---
if [[ "${INCLUDE_PYTHON}" == "no" ]]; then
  log "Python not selected; deleting all Python-related files..."
  FILES_TO_DELETE+=(
    "source/${OLD_NAME}/${OLD_NAME}"
    "source/${OLD_NAME}/test/python_tests"
    "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_py_component.json"
    "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_py_lifecycle_component.json"
  )
else
  if [[ "${INCLUDE_PYTHON_COMPONENT}" == "no" ]]; then
    log "Python Component not selected; deleting Python Component files..."
    FILES_TO_DELETE+=(
      "source/${OLD_NAME}/${OLD_NAME}/py_component.py"
      "source/${OLD_NAME}/test/python_tests/test_py_component.py"
      "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_py_component.json"
    )
  fi
  if [[ "${INCLUDE_PYTHON_LIFECYCLE}" == "no" ]]; then
    log "Python Lifecycle not selected; deleting Python Lifecycle files..."
    FILES_TO_DELETE+=(
      "source/${OLD_NAME}/${OLD_NAME}/py_lifecycle_component.py"
      "source/${OLD_NAME}/test/python_tests/test_py_lifecycle_component.py"
      "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_py_lifecycle_component.json"
    )
  fi
fi

# --- C++-related files ---
if [[ "${INCLUDE_CPP}" == "no" ]]; then
  log "C++ not selected; deleting all C++-related files..."
  FILES_TO_DELETE+=(
    "source/${OLD_NAME}/include"
    "source/${OLD_NAME}/src"
    "source/${OLD_NAME}/test/cpp_tests"
    "source/${OLD_NAME}/test/test_cpp_components.cpp"
    "source/${OLD_NAME}/setup.cfg"
    "source/${OLD_NAME}/requirements.txt"
    "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_cpp_component.json"
    "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_cpp_lifecycle_component.json"
  )
else
  if [[ "${INCLUDE_CPP_COMPONENT}" == "no" ]]; then
    log "C++ Component not selected; deleting C++ Component files..."
    FILES_TO_DELETE+=(
      "source/${OLD_NAME}/src/CPPComponent.cpp"
      "source/${OLD_NAME}/test/cpp_tests/test_cpp_component.cpp"
      "source/${OLD_NAME}/include/${OLD_NAME}/CPPComponent.hpp"
      "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_cpp_component.json"
    )
  fi
  if [[ "${INCLUDE_CPP_LIFECYCLE}" == "no" ]]; then
    log "C++ Lifecycle not selected; deleting C++ Lifecycle files..."
    FILES_TO_DELETE+=(
      "source/${OLD_NAME}/src/CPPLifecycleComponent.cpp"
      "source/${OLD_NAME}/test/cpp_tests/test_cpp_lifecycle_component.cpp"
      "source/${OLD_NAME}/include/${OLD_NAME}/CPPLifecycleComponent.hpp"
      "source/${OLD_NAME}/component_descriptions/${OLD_NAME}_cpp_lifecycle_component.json"
    )
  fi
fi

# Delete the specified files/directories.
for path in "${FILES_TO_DELETE[@]}"; do
  delete_path "${SCRIPT_DIR}/${path}"
done

# --- Modify configuration files ---

# For Python: adjust setup.cfg based on which Python variant is kept.
FILE_TO_MODIFY="${SCRIPT_DIR}/source/${OLD_NAME}/setup.cfg"
if [[ -f "${FILE_TO_MODIFY}" && "${INCLUDE_PYTHON}" == "yes" ]]; then
  if [[ "${INCLUDE_PYTHON_COMPONENT}" == "no" && "${INCLUDE_PYTHON_LIFECYCLE}" == "yes" ]]; then
    log "Removing non-lifecycle Python entry point from setup.cfg..."
    if [[ "${DRY_RUN}" == true ]]; then
      log "Dry run: would remove lines matching '::PyComponent' from ${FILE_TO_MODIFY}"
    else
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/'"${OLD_NAME}"'::PyComponent/d' "${FILE_TO_MODIFY}"
      else
        sed -i '/'"${OLD_NAME}"'::PyComponent/d' "${FILE_TO_MODIFY}"
      fi
    fi
  elif [[ "${INCLUDE_PYTHON_LIFECYCLE}" == "no" && "${INCLUDE_PYTHON_COMPONENT}" == "yes" ]]; then
    log "Removing lifecycle Python entry point from setup.cfg..."
    if [[ "${DRY_RUN}" == true ]]; then
      log "Dry run: would remove lines matching '::PyLifecycleComponent' from ${FILE_TO_MODIFY}"
    else
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/'"${OLD_NAME}"'::PyLifecycleComponent/d' "${FILE_TO_MODIFY}"
      else
        sed -i '/'"${OLD_NAME}"'::PyLifecycleComponent/d' "${FILE_TO_MODIFY}"
      fi
    fi
  fi
fi

# For C++: update CMakeLists.txt only if not in dry-run mode.
CMAKE_FILE="${SCRIPT_DIR}/source/${OLD_NAME}/CMakeLists.txt"
if [[ -f "${CMAKE_FILE}" ]]; then
  log "Updating CMakeLists.txt: ${CMAKE_FILE}..."
  if [[ "${DRY_RUN}" == true ]]; then
    log "Dry run: CMakeLists.txt would be updated (component registrations removed based on selection)."
  else
    if [[ "${INCLUDE_CPP_COMPONENT}" == "no" ]]; then
      log "Removing standard C++ component registration..."
      sed_inplace '/CPPComponent/d' "${CMAKE_FILE}"
      sed_inplace '/cpp_component/d' "${CMAKE_FILE}"
    fi
    if [[ "${INCLUDE_CPP_LIFECYCLE}" == "no" ]]; then
      log "Removing C++ lifecycle component registration..."
      sed_inplace '/CPPLifecycleComponent/d' "${CMAKE_FILE}"
      sed_inplace '/cpp_lifecycle_component/d' "${CMAKE_FILE}"
    fi
    if [[ "${INCLUDE_CPP_COMPONENT}" == "no" && "${INCLUDE_CPP_LIFECYCLE}" == "no" ]]; then
      sed_inplace '/### Register C++ Components ###/d' "${CMAKE_FILE}"
    fi
  fi
fi

if [[ "${DRY_RUN}" == true ]]; then
  log "=== THIS IS A DRY RUN! NO FILE OR FILESYSTEM CHANGES WILL BE MADE ==="
  echo
fi

# Summary of text replacement action.
HYPHENATED_OLD="${OLD_NAME//_/-}"
HYPHENATED_NEW="${NEW_PACKAGE_NAME//_/-}"
log "The following replacements will be performed:"
log "  Text occurrences of:"
log "    - ${OLD_NAME}"
log "    - ${HYPHENATED_OLD}"
log "  will be replaced with:"
log "    - ${NEW_PACKAGE_NAME}"
log "    - ${HYPHENATED_NEW}"
log "in the following files:"
log "  - ${SCRIPT_DIR}/.devcontainer.json"
log "  - ${SCRIPT_DIR}/.github/workflows/build-test.yml"
log "  - ${SCRIPT_DIR}/aica-package.toml"
log "  - All files under ${SCRIPT_DIR}/source/"
echo

# Replace text in fixed files.
replace_text_in_file "${SCRIPT_DIR}/.devcontainer.json"
replace_text_in_file "${SCRIPT_DIR}/.github/workflows/build-test.yml"
replace_text_in_file "${SCRIPT_DIR}/aica-package.toml"

# Process files under source/: replace text and schedule renaming.
declare -a DIRS_TO_RENAME
while IFS= read -r -d '' path; do
  base=$(basename "${path}")
  if [[ -d "${path}" ]]; then
    # Schedule directories for renaming.
    if [[ "${base}" == *"${OLD_NAME}"* ]]; then
      DIRS_TO_RENAME+=("${path}")
    fi
  else
    replace_text_in_file "${path}"
    if [[ "${base}" == *"${OLD_NAME}"* ]]; then
      log "Renaming file:"
      rename_item "${path}"
    fi
  fi
done < <(find "${SCRIPT_DIR}/source" -print0)

# Rename directories in reverse order (deepest first).
for (( idx=${#DIRS_TO_RENAME[@]}-1; idx>=0; idx-- )); do
  log "Renaming directory:"
  rename_item "${DIRS_TO_RENAME[$idx]}"
done

if [[ "${DRY_RUN}" == true ]]; then
  echo
  log "=== THIS WAS A DRY RUN! NO CHANGES WERE MADE ==="
fi
