#!/bin/bash

# Configuration by env:
#  - GIT_BASEURL - base url of git repos
#  - GIT_SUBDIR - whose repo to clone
#  - GIT_SUFFIX - git component dir suffix (default .git)
#  - COMPONENT - component to clone
#  - BRANCH - git branch
#  - NO_CHECK=1 - disable signed tag checking
#  - CLEAN=1 - remove previous sources (use git up vs git clone)
#  - FETCH_ONLY=1 - fetch sources but do not merge
#  - GIT_REMOTE=<remote-name> - use "remote" from git configuration instead of
#    explicit URL
#  - REPO=dir - specify repository directory, component will be guessed based
#    on basename

# Set defaults
GIT_SUBDIR=mainstream
BRANCH=master
GIT_BASEURL=git://git.qubes-os.org
GIT_SUFFIX=.git

[ -r $SCRIPT_DIR/builder.conf ] && source $SCRIPT_DIR/builder.conf

set -e
[ "$DEBUG" = "1" ] && set -x

[ -n "$REPO" ] && COMPONENT="`basename $REPO`"

# Special case for qubes-builder itself
[ "$REPO" == "." ] && COMPONENT="qubes-builder"

[ -z "$COMPONENT" ] && { echo "ERROR: COMPONENT not set!"; exit 1; }

[ -z "$REPO" ] && REPO="$COMPONENT"

url_var="GIT_URL_${COMPONENT/-/_}"

if [ -n "${!url_var}" ]; then
    GIT_URL="${!url_var}"
else
    GIT_URL=$GIT_BASEURL/$GIT_SUBDIR/$COMPONENT$GIT_SUFFIX
fi

# Override GIT_URL with GIT_REMOTE if given
[ -n "$GIT_REMOTE" ] && GIT_URL=$GIT_REMOTE

branch_var="BRANCH_${COMPONENT/-/_}"

if [ -n "${!branch_var}" ]; then
    BRANCH="${!branch_var}"
fi

if [ -d $REPO -a "$CLEAN" != '1' ]; then
    pushd $REPO
    git fetch $GIT_URL --tags || exit 1
    git fetch $GIT_URL $BRANCH || exit 1
    popd > /dev/null
    VERIFY_REF=FETCH_HEAD
else
    rm -rf $REPO
    git clone -b $BRANCH $GIT_URL $COMPONENT
    VERIFY_REF=HEAD
fi

$SCRIPT_DIR/verify-git-tag.sh $REPO $VERIFY_REF || exit 1

if [ "$FETCH_ONLY" != "1" ]; then

[ "$VERIFY_REF" == "FETCH_HEAD" ] && ( cd $REPO; git merge FETCH_HEAD; )

# For additionally download sources
if [ "$COMPONENT" = "xen" -o "$COMPONENT" = "kde-dom0" -o "$COMPONENT" = "antievilmaid" ]; then
    make -C $COMPONENT get-sources
    make -C $COMPONENT verify-sources
fi

if [ "$COMPONENT" = "kernel" ]; then
    make -C $COMPONENT BUILD_FLAVOR=pvops get-sources
    make -C $COMPONENT BUILD_FLAVOR=pvops verify-sources
fi

fi
