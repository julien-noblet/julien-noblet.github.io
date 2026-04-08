#!/usr/bin/env bash

set -euo pipefail

mode="${1:---changed}"

run_markdownlint_all_capture() {
  npx --yes markdownlint-cli2@0.18.1 2>&1 || true
}

list_backlog_files() {
  run_markdownlint_all_capture \
    | awk -F: '/^content\/.*\.(md|markdown):[0-9]+:[0-9]+ / {print $1}' \
    | sort -u
}

is_markdown_path() {
  local path="$1"
  [[ "$path" == content/* ]] && [[ "$path" == *.md || "$path" == *.markdown ]]
}

lint_all() {
  npx --yes markdownlint-cli2@0.18.1
}

lint_batch() {
  local offset="${1:-0}"
  local size="${2:-10}"

  if ! [[ "$offset" =~ ^[0-9]+$ && "$size" =~ ^[0-9]+$ && "$size" -gt 0 ]]; then
    echo "Usage: $0 --batch <offset>=0 <size>=10"
    exit 2
  fi

  mapfile -t files < <(list_backlog_files | tail -n +$((offset + 1)) | head -n "$size")

  if (( ${#files[@]} == 0 )); then
    echo "No markdown files found in backlog for offset=$offset size=$size."
    return 0
  fi

  printf 'Linting batch (%s files):\n' "${#files[@]}"
  printf ' - %s\n' "${files[@]}"

  npx --yes markdownlint-cli2@0.18.1 "${files[@]}" --no-globs
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
  --backlog)
    list_backlog_files
    ;;
  --batch)
    lint_batch "${2:-0}" "${3:-10}"
    ;;
  *)
    echo "Unknown mode: $mode"
    echo "Usage: $0 [--changed|--all|--backlog|--batch <offset> <size>]"
    exit 2
    ;;
esac