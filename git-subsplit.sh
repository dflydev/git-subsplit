#!/usr/bin/env bash
#
# git-subsplit.sh: Automate and simplify the process of managing one-way
# read-only subtree splits.
#
# exit code:
#   1 git checkout/fetch/pull/add-remote operation failed
#   2 git push operation failed
#   3 git subtree operation failed
#
# Copyright (C) 2012 Dragonfly Development Inc.
#
if [ $# -eq 0 ]; then
	set -- -h
fi
OPTS_SPEC="\
git subsplit init    url
git subsplit publish splits --heads=<heads> --tags=<tags> --splits=<splits>
git subsplit update
--
h,help        show the help
q             quiet
debug         show plenty of debug output
n,dry-run     do everything except actually send the updates
work-dir      directory that contains the subsplit working directory

 options for 'publish'
heads=        only publish for listed heads instead of all heads
no-heads      do not publish any heads
tags=         only publish for listed tags instead of all tags
no-tags       do not publish any tags
update        fetch updates from repository before publishing
rebuild-tags  rebuild all tags (as opposed to skipping tags that are already synced)
"
eval "$(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)"

# We can run this from anywhere.
NONGIT_OK=1
DEBUG="  :DEBUG >"

PATH=$PATH:$(git --exec-path)

. git-sh-setup

if [ "$(hash git-subtree &>/dev/null && echo OK)" = "" ]
then
	die "Git subplit needs git subtree; install git subtree or upgrade git to >=1.7.11"
fi

ANNOTATE=
QUIET=
COMMAND=
SPLITS=
REPO_URL=
WORK_DIR="${PWD}/.subsplit"
HEADS=
NO_HEADS=
TAGS=
NO_TAGS=
REBUILD_TAGS=
DRY_RUN=
VERBOSE=

subsplit_main()
{
	while [ $# -gt 0 ]; do
		opt="$1"
		shift
		case "$opt" in
			-q) QUIET=1 ;;
			--debug) VERBOSE=1 ;;
			--heads) HEADS="$1"; shift ;;
			--no-heads) NO_HEADS=1 ;;
			--tags) TAGS="$1"; shift ;;
			--no-tags) NO_TAGS=1 ;;
			--update) UPDATE=1 ;;
			-n) DRY_RUN="--dry-run" ;;
			--dry-run) DRY_RUN="--dry-run" ;;
			--rebuild-tags) REBUILD_TAGS=1 ;;
			--) break ;;
			*) die "Unexpected option: $opt" ;;
		esac
	done

	COMMAND="$1"
	shift

	case "$COMMAND" in
		init)
			if [ $# -lt 1 ]; then die "init command requires url to be passed as first argument"; fi
			REPO_URL="$1"
			shift
			subsplit_init
			;;
		publish)
			if [ $# -lt 1 ]; then die "publish command requires splits to be passed as first argument"; fi
			SPLITS="$1"
			shift
			subsplit_publish
			;;
		update)
			subsplit_update
			;;
		*) die "Unknown command '$COMMAND'" ;;
	esac
}

say()
{
	if [ -z "$QUIET" ];
	then
		echo "$@" >&2
	fi
}

debug()
{
	if [ -n "$VERBOSE" ];
	then
		echo "${DEBUG} $@"
	fi
}

fatal()
{
	RC=${1:-1}
	shift
	say "## Error occured. ${@:-}"
	popd >/dev/null
	exit $RC
}

subsplit_require_work_dir()
{
	if [ ! -e "$WORK_DIR" ]
	then
		die "Working directory not found at ${WORK_DIR}; please run init first"
	fi

	debug "EXECUTE: pushd \"${WORK_DIR}\" >/dev/null"
	pushd "$WORK_DIR" >/dev/null
}

subsplit_init()
{
	if [ -e "$WORK_DIR" ]
	then
		die "Working directory already found at ${WORK_DIR}; please remove or run update"
	fi

	say "Initializing subsplit from origin (${REPO_URL})"
	debug "EXECUTE: git clone -q \"${REPO_URL}\" \"${WORK_DIR}\""
	git clone -q "$REPO_URL" "$WORK_DIR" || die "Could not clone repository"
}

subsplit_publish()
{
	subsplit_require_work_dir

	if [ -n "$UPDATE" ];
	then
		subsplit_update
	fi

	if [ -z "$HEADS" ] && [ -z "$NO_HEADS" ]
	then
		# If heads are not specified and we want heads, discover them.
		HEADS="$(git ls-remote origin 2>/dev/null | grep "refs/heads/" | cut -f3- -d/)"
		debug "HEADS=\"${HEADS}\""
	fi

	if [ -z "$TAGS" ] && [ -z "$NO_TAGS" ]
	then
		# If tags are not specified and we want tags, discover them.
		TAGS="$(git ls-remote origin 2>/dev/null | grep -v "\^{}" | grep "refs/tags/" | cut -f3 -d/)"
		debug "TAGS=\"${TAGS}\""
	fi

	for SPLIT in $SPLITS
	do
		SUBPATH=$(echo "$SPLIT" | cut -f1 -d:)
		REMOTE_URL=$(echo "$SPLIT" | cut -f2- -d:)
		REMOTE_NAME=$(echo "$SPLIT" | git hash-object --stdin)

		debug "SUBPATH=${SUBPATH}"
		debug "REMOTE_URL=${REMOTE_URL}"
		debug "REMOTE_NAME=${REMOTE_NAME}"

		if ! git remote | grep "^${REMOTE_NAME}$" >/dev/null
		then
			debug "EXECUTE: git remote add \"${REMOTE_NAME}\" \"${REMOTE_URL}\""
			git remote add "$REMOTE_NAME" "$REMOTE_URL" \
				|| fatal 1 "Command failed: git remote add \"${REMOTE_NAME}\" \"${REMOTE_URL}\""
		fi


		say "Syncing ${SUBPATH} -> ${REMOTE_URL}"

		for HEAD in $HEADS
		do
			debug "git show-ref --quiet --verify -- \"refs/remotes/origin/${HEAD}\""
			if ! git show-ref --quiet --verify -- "refs/remotes/origin/${HEAD}"
			then
				say " - skipping head '${HEAD}' (does not exist)"
				continue
			fi
			LOCAL_BRANCH="${REMOTE_NAME}-branch-${HEAD}"

			debug "LOCAL_BRANCH=\"${LOCAL_BRANCH}\""

			say " - syncing branch '${HEAD}'"

			debug "EXECUTE: git checkout master >/dev/null 2>&1"
			git checkout master >/dev/null 2>&1 \
				|| fatal 1 "Command failed: git checkout master >/dev/null 2>&1"

			debug "EXECUTE: git branch -D \"$LOCAL_BRANCH\" >/dev/null 2>&1"
			git branch -D "$LOCAL_BRANCH" >/dev/null 2>&1

			debug "EXECUTE: git branch -D \"${LOCAL_BRANCH}-checkout\" >/dev/null 2>&1"
			git branch -D "${LOCAL_BRANCH}-checkout" >/dev/null 2>&1

			debug "EXECUTE: git checkout -b \"${LOCAL_BRANCH}-checkout\" \"origin/${HEAD}\" >/dev/null 2>&1"
			git checkout -b "${LOCAL_BRANCH}-checkout" "origin/${HEAD}" >/dev/null 2>&1 \
				|| fatal 1 "Command failed: git checkout -b \"${LOCAL_BRANCH}-checkout\" \"origin/${HEAD}\" >/dev/null 2>&1"

			debug "EXECUTE: git subtree split -q --prefix=\"$SUBPATH\" --branch=\"$LOCAL_BRANCH\" \"origin/${HEAD}\" >/dev/null"
			git subtree split -q --prefix="$SUBPATH" --branch="$LOCAL_BRANCH" "origin/${HEAD}" >/dev/null \
				|| fatal 3 "Command failed: git subtree split -q --prefix=\"$SUBPATH\" --branch=\"$LOCAL_BRANCH\" \"origin/${HEAD}\" >/dev/null"

			PUSH_CMD="git push -q ${DRY_RUN} --force $REMOTE_NAME ${LOCAL_BRANCH}:${HEAD}"
			debug "EXECUTE: $PUSH_CMD"
			[ -n "$DRY_RUN" ] && echo \# $PUSH_CMD
			$PUSH_CMD || fatal 2 "Command failed: $PUSH_CMD"
		done

		for TAG in $TAGS
		do
			debug "git show-ref --quiet --verify -- \"refs/tags/${TAG}\""

			if ! git show-ref --quiet --verify -- "refs/tags/${TAG}"
			then
				say " - skipping tag '${TAG}' (does not exist)"
				continue
			fi
			LOCAL_TAG="${REMOTE_NAME}-tag-${TAG}"

			debug "LOCAL_TAG="${LOCAL_TAG}""

			if git branch | grep "${LOCAL_TAG}$" >/dev/null && [ -z "$REBUILD_TAGS" ]
			then
				say " - skipping tag '${TAG}' (already synced)"
				continue
			fi

			debug "git branch | grep \"${LOCAL_TAG}$\" >/dev/null && [ -z \"${REBUILD_TAGS}\" ]"

			say " - syncing tag '${TAG}'"
			say " - deleting '${LOCAL_TAG}'"

			debug "EXECUTE: git branch -D \"${LOCAL_TAG}\" >/dev/null 2>&1"
			git branch -D "$LOCAL_TAG" >/dev/null 2>&1

			say " - subtree split for '${TAG}'"
			debug "EXECUTE: git subtree split -q --annotate=\"${ANNOTATE}\" --prefix=\"$SUBPATH\" --branch=\"$LOCAL_TAG\" \"$TAG\" >/dev/null"
			git subtree split -q --annotate="${ANNOTATE}" --prefix="$SUBPATH" --branch="$LOCAL_TAG" "$TAG" >/dev/null \
				|| fatal 3 "Command failed: git subtree split -q --annotate=\"${ANNOTATE}\" --prefix=\"$SUBPATH\" --branch=\"$LOCAL_TAG\" \"$TAG\" >/dev/null"

			say " - subtree split for '${TAG}' [DONE]"
			PUSH_CMD="git push -q ${DRY_RUN} --force ${REMOTE_NAME} ${LOCAL_TAG}:refs/tags/${TAG}"
			debug "EXECUTE: $PUSH_CMD"
			[ -n "$DRY_RUN" ] && echo \# $PUSH_CMD
			$PUSH_CMD || fatal 2 "Command failed: $PUSH_CMD"
		done
	done

	popd >/dev/null
}

subsplit_update()
{
	subsplit_require_work_dir

	say "Updating subsplit from origin"

	debug "EXECUTE: git fetch -q -t origin"
	git fetch -q -t origin || fatal 1 "Command failed: git fetch -q -t origin"

	debug "EXECUTE: git checkout master"
	git checkout master || fatal 1 "Command failed: git checkout master"

	debug "EXECUTE: git reset --hard origin/master"
	git reset --hard origin/master || fatal 1 "Command failed: git reset --hard origin/master"

	popd >/dev/null
}

subsplit_main "$@"
