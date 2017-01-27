#!bash
#
# git-subsplit-completion
# ===================
#
# Bash completion support for [git-subsplit](https://github.com/dflydev/git-subsplit)
#
# The contained completion routines provide support for completing:
#
#  * git-subsplit init, publish and update
#
# Installation
# ------------
#
# To achieve git-subsplit completion nirvana:
#
#  0. Install git-completion.
#
#  1. Install this file. Either:
#
#     a. Place it in a `bash-completion.d` folder:
#
#        * /etc/bash-completion.d
#        * /usr/local/etc/bash-completion.d
#        * ~/bash-completion.d
#
#     b. Or, copy it somewhere (e.g. ~/.git-subsplit-completion.sh) and put the following line in
#        your .bashrc:
#
#            source ~/.git-git-subsplit.sh
#
#  2. If you are using Git < 1.7.1: Edit git-completion.sh and add the following line to the giant
#     $command case in _git:
#
#         subsplit)        _git_subsplit ;;
#
# Copyright (c) 2016 Bogdan Padalko <zaq178miami@gmail.com>
#
# Licensed under the MIT license: http://opensource.org/licenses/MIT
#
# Based on [git-flow-completion.bash](https://github.com/bobthecow/git-flow-completion/blob/master/git-flow-completion.bash)
# and [git-completion.bash](https://github.com/git/git/blob/master/contrib/completion/git-completion.bash)

_git_subsplit ()
{
    __git_has_doubledash && return

    local subcommands="init publish update"
    local subcommand="$(__git_find_on_cmdline "$subcommands")"
    if [ -z "$subcommand" ]; then
        case "$cur" in
        --*)
            __gitcomp "--help --debug --dry-run --work-dir"
            ;;
        -*)
            __gitcomp "-h -q -n"
            ;;
        *)
            __gitcomp "$subcommands"
            ;;
        esac
        return
    fi

    case "$subcommand" in
        publish)
        __git_subsplit_publish
        ;;
    *)
        ;;
    esac
}

__git_subsplit_publish ()
{

    case "$cur" in
    --heads=*)
        __gitcomp_nl "$(__git_heads)" "" "${cur##--heads=}"
        return
        ;;
    --tags=*)
        __gitcomp_nl "$(__git_tags)" "" "${cur##--tags=}"
        ;;
    --*)
        __gitcomp "--heads --no-heads --tags --no-tags --update --rebuild-tags"
        ;;
    *)
        __gitcomp "$subcommands"
        ;;
    esac
    return
}

# alias __git_find_on_cmdline for backwards compatibility
if [ -z "`type -t __git_find_on_cmdline`" ]; then
    alias __git_find_on_cmdline=__git_find_subcommand
fi
