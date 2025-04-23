#!/bin/bash

docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  --build-arg GO_PLUGINS_CACHE_BUSTER=$(date +%s) \
  -t pb-compiler .
