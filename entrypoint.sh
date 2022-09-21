#!/usr/bin/env bash

# set -x
NL=\\\\n
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

PROTO_COMPILE_DELAY=${PROTO_COMPILE_DELAY:=4000}
PROTO_OUT_BASE=/app/proto
GO_TARGET="go"
CJS_TARGET="commonjs"

_go_basedir=/app/autogen/go
_cjs_basedir=/app/autogen/cjs

# Read the target platforms into an array variable.
# Supported platforms: commonjs, go
# IFS=',' read -r -a proto_targets <<< $PROTO_TARGETS

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
  echo -n $(sed -i -r "/^\s*package\s+[^;]+;/a${NL}option go_package = \"$GS_GO_IMPORT_PREFIX/$go_path_postfix\";" $file)
}

compile_go_proto() {
  local tmstmp=proto-go-$(date +%s)
  local proto_tmp="/tmp/$tmstmp"
  local proto_out="${_go_basedir}"

  mkdir -p $proto_tmp
  mkdir -p $proto_out
  rm -rf $proto_out/${GS_ADDON_NAME}/*
  # Copy proto files to compile
  cp -r /share/* $proto_tmp/

  started_at "auto-generating go_option"
  find $proto_tmp -name '*.proto' -type f | while read file;
    do
      echo -e "\t...$(basename $file)"
      autogen_go_package_option $file
    done
  _done

  started_at "compiling proto files, target Golang"
  find $proto_tmp -name '*.proto' -type f | while read file;
    do
      echo -e "\t...$(basename $file)"
      protoc -I"$proto_tmp" \
        --go_opt=paths=source_relative \
        --go-grpc_opt=paths=source_relative \
        --go_out=$proto_out \
        --go-grpc_out=$proto_out \
        $file
    done
  _done

  rm -rf $proto_tmp
  chown -R $USER_ID:$GROUP_ID $proto_out
}

compile_cjs_proto() {
  local tmstmp=proto-cjs-$(date +%s)
  local proto_tmp="/tmp/$tmstmp"
  local proto_out="${_cjs_basedir}"

  mkdir -p $proto_tmp
  mkdir -p $proto_out
  rm -rf $proto_out/*
  # Copy proto files to compile
  cp -r /share/* $proto_tmp/

  started_at "compiling proto files, target CommonJS"
  find $proto_tmp -name '*.proto' -type f | while read file;
    do
      echo -e "\t...$(basename $file)"
      protoc \
        -I"$proto_tmp" \
        --js_out=import_style=commonjs,binary:$proto_out \
        --ts_out=service=grpc-web:$proto_out \
        $file
    done
  _done

  rm -rf $proto_tmp
  chown -R $USER_ID:$GROUP_ID $proto_out
}

compile_all() {
    if [[ -d "$_go_basedir" ]]; then
      compile_go_proto
    fi
    if [[ -d "$_cjs_basedir" ]]; then
      compile_cjs_proto
    fi
}

#
#
#
source ~/.profile

#
compile_all

# Monitor changes of all proto files and compile them after each change
inotifywait -m -e close_write -e delete -r --include='.proto$' /share \
  | debounce -t $PROTO_COMPILE_DELAY --replace-input="$(echo)" \
  | while read;
do
  compile_all
done
