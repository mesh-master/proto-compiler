#!/usr/bin/env sh

# Golang linter
if ! which golangci-lint &>/dev/null; then
  echo "Installing golangci-lint..."
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
  | sh -s -- -b $(go env GOPATH)/bin v1.44.2
else
  echo "golangci-lint has been found, skipping installation"
fi
