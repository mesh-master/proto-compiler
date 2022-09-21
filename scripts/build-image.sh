#!/bin/bash

PROTOBUF_VER=${PROTOBUF_VER:=3.19.4}

docker build \
  --build-arg PROTOBUF_VER="$PROTOBUF_VER" \
  -t go-serv_proto-compiler \
  .
