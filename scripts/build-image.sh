#!/bin/bash

PROTOBUF_VER=${PROTOBUF_VER:=3.19.4}

docker build \
  --build-arg PROTOBUF_VER="$PROTOBUF_VER" \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t go-serv_proto-compiler \
  .
