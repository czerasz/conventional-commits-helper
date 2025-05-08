#!/usr/bin/env bash

set -eu -o pipefail

script_directory="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_directory="${script_directory}/.."

export GUM_LOG_LEVEL="${LOG_LEVEL:-ERROR}"

dry_run="${DRY_RUN:-false}"

gum_version='0.16.0'
gum_version_slug=$(echo "${gum_version}" | sed 's/\./-/')
cache_path="${HOME}/.cache/conventional-commits-helper"
gum_path="${cache_path}/bin/gum-${gum_version_slug}"

if [ ! -f "${gum_path}" ]; then
  os='Linux'
  arch='x86_64'

  tmp_path="${cache_path}/tmp"
  mkdir -p "${tmp_path}"
  cd "${tmp_path}"

  archive="gum_${gum_version}_${os}_${arch}.tar.gz"

  curl -sSLO "https://github.com/charmbracelet/gum/releases/download/v${gum_version}/checksums.txt"
  curl -sSLO "https://github.com/charmbracelet/gum/releases/download/v${gum_version}/${archive}"

  grep "${archive}" checksums.txt | grep -E 'tar.gz$' | sha256sum -c -

  # cleanup
  rm checksums.txt

  tar -xf "${archive}" "gum_${gum_version}_${os}_${arch}/gum"
  rm "${archive}"

  mkdir -p $(dirname "${gum_path}")
  mv "gum_${gum_version}_${os}_${arch}/gum" "${gum_path}"
  rm -r "gum_${gum_version}_${os}_${arch}"

  cd -
fi

cmd="${1:-undefined}"

if [ "${cmd}" == 'commit' ]; then
  types=$(cat <<EOS
feat - new feature||feat
fix - fix something||fix
refactor - refactoring||refactor
style - styling changes||style
docs - documentation adjustments||docs
chore - just another commit||chore
build - build adjustments||build
ci - CI/CD||ci
perf - performace adjustments||perf
test - changed tests||test
EOS
)

  type=$(echo "${types}" | "${gum_path}" choose --header='Choose commit type:' --label-delimiter="||")

  "${gum_path}" log --level debug "type: ${type}"

  scopes=$(cat <<EOS
none
api
lang
parser
EOS
)

  scope=$(echo "${scopes}" | GUM_CHOOSE_SELECTED='none' "${gum_path}" choose --header='Choose commit scope:')

  "${gum_path}" log --level debug "scope: ${scope}"


  msg=$("${gum_path}" input --placeholder='Commit message...')

  git_commit="${type}"

  if [ "${scope}" != 'none' ]; then
    git_commit="${git_commit}(${scope})"
  fi

  git_commit="${git_commit}: ${msg}"

  "${gum_path}" log --level debug "conventional commit: ${git_commit}"

  if [ "${dry_run}" == 'false' ]; then
    git commit -m "${git_commit}"
  fi
elif [ "${cmd}" == 'create-branch' ]; then
  types=$(cat <<EOS
feature - new feature||feature
fix - fix something||fix
refactor - refactoring||refactor
docs - documentation adjustments||docs
ci - CI/CD||ci
EOS
)
  type=$(echo "${types}" | "${gum_path}" choose --header='Choose branch type:' --label-delimiter="||")

  "${gum_path}" log --level debug "type: ${type}"

  ticket_prefix="${CCH_TICKET_PREFIX:-}"
  ticket=$("${gum_path}" input --prompt="> ${ticket_prefix}" --placeholder='Ticket ID')

  "${gum_path}" log --level debug "ticket: ${ticket}"

  if [ "${ticket}" != '' ]; then
    ticket="${ticket}-"
  fi

  git_branch="${type}/${ticket_prefix}${ticket}"

  desc=$("${gum_path}" input --placeholder='Description')

  desc_slug=$(echo "${desc}" | tr '[A-Z]' '[a-z]' | sed 's|[ .,]|_|g' | sed -E 's|_+|-|g')

  git_branch="${git_branch}${desc_slug}"

  "${gum_path}" log --level debug "${git_branch}"

  if [ "${dry_run}" == 'false' ]; then
    git checkout -b "${git_branch}"
  fi
else
  "${gum_path}" log --level error 'no command specified'

  cat <<EOS
Usage: cch <command>

A conventional commits helper tool.

Commands:
  commit           Structure git commit messages according
  create-branch    Create git branch
EOS
fi
