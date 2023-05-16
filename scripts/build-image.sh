#!/bin/bash

PROTOBUF_VER=${PROTOBUF_VER:=3.19.4}

docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t pb-compiler \
  .
