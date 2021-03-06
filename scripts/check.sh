#!/usr/bin/env bash

set -exuo pipefail

export TOP=${TOP:-$(git rev-parse --show-toplevel)}
UPSTREAM_REMOTE=${UPSTREAM_REMOTE:-origin}

git fetch $(git remote get-url $UPSTREAM_REMOTE) master
UPSTREAM_BRANCH=FETCH_HEAD

if ! $TOP/scripts/git-assert-clean.sh; \
then \
  echo >&2 "Please commit your changes!"; \
  exit 1; \
fi
UPSTREAM_REV=$(git rev-parse $UPSTREAM_BRANCH)
if ! $TOP/scripts/git-rebased-on.sh $UPSTREAM_REV --linear; \
then \
  echo >&2 "Please rebase your branch onto ‘$UPSTREAM_BRANCH’!"; \
  exit 1; \
fi
$TOP/scripts/stylish.sh
if ! $TOP/scripts/git-assert-clean.sh; \
then \
  echo >&2 "Please run ‘scripts/stylish.sh’ to fix style errors!"; \
  exit 1; \
fi
