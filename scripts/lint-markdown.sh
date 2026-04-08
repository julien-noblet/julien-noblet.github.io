#!/usr/bin/env bash

set -euo pipefail

mode="${1:---changed}"

is_markdown_path() {
  local path="$1"
  [[ "$path" == content/* ]] && [[ "$path" == *.md || "$path" == *.markdown ]]
}

lint_all() {
  npx --yes markdownlint-cli2@0.18.1
}

lint_changed_local() {
  declare -A seen=()
  declare -a files=()

  while IFS= read -r -d '' path; do
    if is_markdown_path "$path" && [[ -z "${seen[$path]+x}" ]]; then
      seen["$path"]=1
      files+=("$path")
    fi
  done < <(git diff --name-only -z --diff-filter=ACMRT HEAD --)

  while IFS= read -r -d '' path; do
    if is_markdown_path "$path" && [[ -z "${seen[$path]+x}" ]]; then
      seen["$path"]=1
      files+=("$path")
    fi
  done < <(git ls-files --others --exclude-standard -z)

  if (( ${#files[@]} == 0 )); then
    echo "No changed markdown files to lint."
    return 0
  fi

  npx --yes markdownlint-cli2@0.18.1 "${files[@]}" --no-globs
}

case "$mode" in
  --all)
    lint_all
    ;;
  --changed)
    lint_changed_local
    ;;
  *)
    echo "Unknown mode: $mode"
    echo "Usage: $0 [--changed|--all]"
    exit 2
    ;;
esac