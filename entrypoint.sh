#!/usr/bin/env bash

# set -x
NL=\\\\n
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

PROTO_COMPILE_DELAY=${PROTO_COMPILE_DELAY:=4000}
PROTO_OUT_BASE=/app/proto
GO_TARGET="go"
CJS_TARGET="commonjs"

# Read the target platforms into an array variable.
# Supported platforms: commonjs, go
IFS=',' read -r -a proto_targets <<< $PROTO_TARGETS

_done() {
  echo -e "${BOLD}\tdone\n${NORMAL}"
}

started_at() {
  local msg=$1
  echo -e "${BGreen}$(date +"%Y-%m-%d %H:%M:%S"):${Color_Off} ${UBlack}$msg${Color_Off}"
}

get_package_name() {
  local file=$1
  echo -n $(gawk -e 'match($0, /^\s*package\s+([a-zA-Z0-9_.]+);$/, m) {print m[1]}' $file)
}

get_go_path_postfix() {
  local file=$1
  echo -n $(get_package_name $file | tr '.' '/')
}

autogen_go_package_option() {
  local file=$1
  local go_path_postfix=$(get_go_path_postfix $file)
  echo -n $(sed -i -r "/^\s*package\s+[^;]+;/a${NL}option go_package = \"$PROTOBUF_GO_IMPORT_PREFIX/$go_path_postfix\";" $file)
}

compile_proto() {
  local target=${1:=go}
  local tmstmp=$(date +%s)
  local proto_dir="/tmp/proto/$tmstmp/$target"
  local proto_out="/tmp/proto/$tmstmp/$target-compiled"

  mkdir -p $proto_dir
  mkdir -p $proto_out
  # Copy proto files to compile
  cp -r /share/* $proto_dir/

  if [ $target == $GO_TARGET ]; then
    started_at "auto-generating go_option"
    find $proto_dir -name '*.proto' -type f | while read file;
      do
        echo -e "\t...$(basename $file)"
        autogen_go_package_option $file
      done
    _done
  fi

  started_at "compiling proto files for the target: $target"
  find $proto_dir -name '*.proto' -type f | while read file;
    do
      echo -e "\t...$(basename $file)"
      # Go
      if [ $target == $GO_TARGET ]; then
        protoc -I"$proto_dir" \
          --go_opt=paths=source_relative \
          --go-grpc_opt=paths=source_relative \
          --go_out=$proto_out \
          --go-grpc_out=$proto_out \
          $file
      fi
      # CommonJS
      if [ $target == $CJS_TARGET ]; then
        protoc \
          -I"$proto_dir" \
          --js_out=import_style=commonjs,binary:$proto_out \
          --ts_out=service=grpc-web:$proto_out \
          $file
      fi
    done
  _done

  # Copy compiled proto files.
  rm -rf $PROTO_OUT_BASE/$target/*
  cp -r $proto_out/* $PROTO_OUT_BASE/$target/
  chown -R $USER_ID:$GROUP_ID $PROTO_OUT_BASE/$target
  rm -rf $proto_out
  rm -rf $proto_dir
}

#
#
#
if [ ! -d $proto_compiled_mounted_dir ]; then
  echo "Output directory $proto_compiled_mounted_dir for the compiled proto files must be mounted on a host one"
  exit 1
fi

if [ -z $PROTOBUF_GO_IMPORT_PREFIX ]; then
  echo "PROTOBUF_GO_IMPORT_PREFIX env variable must not be empty"
  exit 1
fi

source ~/.profile

# Monitor changes of all proto files and compile them after each change
inotifywait -m -e close_write -e delete -r --include='.proto$' /share \
  | debounce -t $PROTO_COMPILE_DELAY --replace-input="$(echo)" \
  | while read;
do
  for t in "${proto_targets[@]}"; do
    compile_proto $t
  done
done
