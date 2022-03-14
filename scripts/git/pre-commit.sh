#!/usr/bin/env bash

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" >/dev/null && pwd)"

golangci-lint run $REPO_DIR/...

exit $?