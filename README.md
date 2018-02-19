Git Subsplit
============

Automate and simplify the process of managing one-way read-only
subtree splits.

Git subsplit relies on `subtree` being available. If is not available
in your version of git (likely true for versions older than 1.7.11)
please install it manually from [here](https://github.com/apenwarr/git-subtree).


Install
-------

git-subsplit can be installed and run standalone by executing
`git-subsplit.sh`  directly.

git-subsplit can also be installed as a git command by:

    ./install.sh

Caveats
-------

There is a known bug in the underlying git-subtree command that this script uses. Your disk will eventually run out of inodes because a cache directory isn't cleaned up after every run. I suggest you to create a cronjob to clean the cache directory every month:

```
0	0	1	*	*	 rm -rf <path to>/dflydev-git-subsplit-github-webhook/temp/$projectname/.subsplit/.git/subtree-cache/*
```

Hooks
-----

### GitHub WebHooks

 * [dflydev GitHub WebHook](https://github.com/dflydev/dflydev-git-subsplit-github-webhook) (**PHP**)


Usage
-----

### Initialize

Initialize subsplit with a git repository url:

    git subsplit init https://github.com/react-php/react

This will create a working directory for the subsplit. It will contain
a clone of the project's upstream repository.


### Update

Update the subsplit repository with current state of its upstream
repository:

    git subsplit update

This command should be called before one or more `publish` commands
are called to ensure that the repository in the working directory
has been updated from its upstream repository.


### Publish

Publish to each subtree split to its own repository:

    git subsplit publish \
        src/React/EventLoop:git@github.com:react-php/event-loop.git \
        --heads=master

The pattern for the splits is `${subPath}:${url}`. Publish can receive
its splits argument as a space separated list:

    git subsplit publish "
        src/React/EventLoop:git@github.com:react-php/event-loop.git
        src/React/Stream/:git@github.com:react-php/stream.git
        src/React/Socket/:git@github.com:react-php/socket.git
        src/React/Http/:git@github.com:react-php/http.git
        src/React/Espresso/:git@github.com:react-php/espresso.git
    " --heads=master

This command will create subtree splits of the project's repository
branches and tags. It will then push each branch and tag to the
repository dedicated to the subtree.


#### --update

Passing `--update` to the `publish` command is a shortcut for calling
the `update` command directly.


#### --heads=\<heads\>

To specify a list of heads (instead of letting git-subsplit discover them
from the upstream repository) you can specify them directly. For example:

    --heads="master 2.0"

The above will only sync the master and 2.0 branches, no matter which
branches the upstream repository knows about.


#### --no-heads

Do not sync any heads.


#### --search-heads

To search for a list of possible heads and publish only the matches.

    --search-heads="refs/heads/master\|refs/heads/develop\|refs/heads/release-"

The above will only publish branches that are either `master`, `develop`
or any other branch of the form `release-*`.

[Grep](https://www.gnu.org/savannah-checkouts/gnu/grep/manual/grep.html) patterns will be applied.


#### --tags=\<tags\>

To specify a list of tags (instead of letting git-subsplit discover them
from the upstream repository) you can specify them directly. For example:

    --tags="v1.0.0 v1.0.3"

The above will only sync the v1.0.0 and v1.0.3 tags, no matter which
tags the upstream repository knows about.


#### --no-tags

Do not sync any tags.


#### --rebuild-tags

Ordinarily tags will not be synced more than once. This is because in general
tags should be considered more or less static.

If for some reason tags need to be resynced from scratch (history changed so
tags might point to somewhere else) this flag will get the job done.


#### -q,--quiet

As little output as possible.


#### -n,--dry-run

Does not actually publish information to the subsplit repos for each
subtree split. Instead, display the command and execute the command
with `--dry-run` included.

#### --debug

Allows you to see the logic behind the scenes.


Not Invented Here
-----------------

Inspiration for writing this came from [Guzzle's](http://guzzlephp.org/)
goal of providing components as individually managed packages. Having
seen this already done by [Symfony](http://symfony.com) and liking how
it behaved I wanted to try and see if I could solve this problem in a
general case so more people could take advantage of this workflow.

Much time was spent checking out `git-subtree` and scripts written for
managing [React's](http://nodephp.org/) components.


License
-------

MIT, see LICENSE.


Community
---------

If you have questions or want to help out, join us in the
**#dflydev** channel on irc.freenode.net.
