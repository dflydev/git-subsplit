pkg_name=git-subsplit
pkg_origin=dflydev
pkg_maintainer="Beau Simensen <hello@dflydev.com>"
pkg_license=("MIT")
pkg_upstream_url=https://github.com/dflydev/git-subsplit

pkg_build_deps=(
  core/git
)

pkg_deps=(
  core/bash
)

pkg_bin_dirs=(bin)


# implement git-based dynamic version strings
pkg_version() {
  if [ -n "${pkg_last_tag}" ]; then
    echo "${pkg_last_version}-git+${pkg_last_tag_distance}.${pkg_commit}"
  else
    echo "${pkg_last_version}-git+${pkg_commit}"
  fi
}


# implement in-git build workflow
do_before() {
  do_default_before

  # configure git repository
  export GIT_DIR="${PLAN_CONTEXT}/../.git"

  # load version information from git
  pkg_commit="$(git rev-parse --short HEAD)"
  pkg_last_tag="$(git describe --tags --abbrev=0 ${pkg_commit} || true 2>/dev/null)"

  if [ -n "${pkg_last_tag}" ]; then
    pkg_last_version=${pkg_last_tag#v}
    pkg_last_tag_distance="$(git rev-list ${pkg_last_tag}..${pkg_commit} --count)"
  else
    pkg_last_version="0.0.0"
  fi

  # initialize pkg_version
  update_pkg_version
}

do_unpack() {
  mkdir "${CACHE_PATH}"
  build_line "Extracting ${GIT_DIR}#${pkg_commit}"
  git archive "${pkg_commit}" | tar -x --directory="${CACHE_PATH}"
}

do_build() {
  pushd "${CACHE_PATH}" > /dev/null

  build_line "Fixing interpreter"
  sed -e "s#\#\!/usr/bin/env bash#\#\!$(pkg_path_for bash)/bin/bash#" --in-place "./git-subsplit.sh"

  popd > /dev/null
}

do_install() {
  cp -v "${CACHE_PATH}/git-subsplit.sh" "${pkg_prefix}/bin/git-subsplit"
}

do_strip() {
  return 0
}