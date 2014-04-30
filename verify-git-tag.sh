#!/bin/sh

# Usage: $0 <source-dir> [<ref>]
# Example refs:
#  master
#  HEAD
#  mainstream/master
# Default ref: HEAD

if [ "$NO_CHECK" == "1" ]; then
	exit 0
fi

if [ -n "$KEYRING_DIR_GIT" ]; then
    export GNUPGHOME="`readlink -m $KEYRING_DIR_GIT`"
    if [ ! -d "$GNUPGHOME" ]; then
        mkdir -p $GNUPGHOME
        chmod 700 $GNUPGHOME
        gpg --import qubes-developers-keys.asc
        # Trust Qubes Master Signing Key
        echo '427F11FD0FAA4B080123F01CDDFA1A3E36879494:6:' | gpg --import-ownertrust
    fi
    if [ qubes-developers-keys.asc -nt "$GNUPGHOME/pubring.gpg" ]; then
        gpg --import qubes-developers-keys.asc
        touch "$GNUPGHOME/pubring.gpg"
    fi
fi


pushd $1 > /dev/null

if [ -n "$2" ]; then
	REF="$2"
else
	REF="HEAD"
fi

verify_tag() {
	sig_header="-----BEGIN PGP SIGNATURE-----"
	temp_name=`mktemp -d sig-verify.XXXXXX`
	git cat-file tag $1 | sed "/$sig_header/,//d"  > $temp_name/content
	git cat-file tag $1 | sed -n "/$sig_header/,//p" > $temp_name/content.asc
	gpg --verify --status-fd=1 $temp_name/content.asc 2>/dev/null|grep -q '^\[GNUPG:\] TRUST_\(FULLY\|ULTIMATE\)$'
	ret=$?
	rm -r $temp_name
	return $ret
}

VALID_TAG_FOUND=0
for tag in `git tag --points-at=$REF`; do
	if verify_tag $tag; then
		VALID_TAG_FOUND=1
	else
		if [ "0$VERBOSE" -ge 1 ]; then
			echo "---> One of signed tag cannot be verified:"
			git tag -v $tag
		fi
	fi
done

if [ "$VALID_TAG_FOUND" -eq 0 ]; then
	echo "No valid signed tag found!"
    if [ "0$VERBOSE" -eq 0 -a -n "`git describe $REF`" ]; then
        echo "---> One of invalid tag:"
        git tag -v `git describe $REF`
    fi
	exit 1
fi

exit 0
