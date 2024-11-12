#!/usr/bin/env bash

# set -x
NL=\\\\n
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

PROTO_COMPILE_DELAY=${PROTO_COMPILE_DELAY:=4000}
PROTO_SOURCE_DIR=${PROTO_SOURCE_DIR:=/proto/source}

NANOPB_COMPILER=/nanopb/generator/nanopb_generator
NANOPB_COMPILER_OPTS=${NANOPB_COMPILER_OPTS:=-t -q}

nanopb_out=/proto/autogen/nanopb
go_out=/proto/autogen/go

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

basename_with_parent() {
  local parentdir
  parentdir=$(basename "$(dirname "$1")")
  echo  "$parentdir"/$(basename $1)
}

get_go_path_postfix() {
  local file=$1
  echo -n $(get_package_name $file | tr '.' '/')
}

autogen_go_package_option() {
  local file=$1
  local go_path_postfix=$(get_go_path_postfix $file)
  echo -n $(sed -i -r "/^\s*package\s+[^;]+;/a${NL}option go_package = \"$PROTO_GO_IMPORT_PREFIX/$go_path_postfix\";" $file)
}

compile_go() {
  local tmp_proto_dir=/tmp/proto_source

  rm -rf $go_out/*
  rm -rf $tmp_proto_dir

  mkdir -p $tmp_proto_dir
  cp -r "$PROTO_SOURCE_DIR"/* $tmp_proto_dir

  started_at "auto-generating go_option"
  find $tmp_proto_dir -name '*.proto' -type f | while read file;
    do
      autogen_go_package_option $file
    done
  _done

  started_at "compiling proto files, target Golang"
  find $tmp_proto_dir -name '*.proto' -type f | while read file;
    do
      echo -e "\t$(basename_with_parent $file)"
      protoc -I$tmp_proto_dir \
        --go_opt=paths=source_relative \
        --go-grpc_opt=paths=source_relative \
        --go_out=$go_out \
        --go-grpc_out=$go_out \
        $file
    done
  _done

  chown -R $USER_ID:$GROUP_ID $go_out
}

compile_nanopb() {
  started_at "compiling proto files, target embedded C"

  rm -rf $nanopb_out/*

  find $PROTO_SOURCE_DIR -name '*.proto' -type f | while read file;
    do
      if grep -q '//+nanopb' $file; then
        if ! $NANOPB_COMPILER $NANOPB_COMPILER_OPTS -I$PROTO_SOURCE_DIR -D $nanopb_out $file; then
          echo "error compiling $file"
          exit 1
        fi
        echo -e "\t$(basename_with_parent $file)"
      fi
    done
  _done

  # fix filesystem ownership
  chown -R $USER_ID:$GROUP_ID $nanopb_out
}

compile() {
    if [[ -d $go_out ]]; then
      compile_go
    fi

    if [[ -d $nanopb_out ]]; then
      compile_nanopb
    fi
}

#
source ~/.profile

if [[ ! -d $PROTO_SOURCE_DIR ]]; then
  echo "nothing to compile, please specify a source directory"
  exit
fi

if [[ ! -d $nanopb_out ]] && [[ ! -d $go_out ]]; then
  echo "specify compilation target: nanopb, go"
  exit
fi

# Compile at container start.
compile

# Monitor changes of all proto files and compile them after each change
inotifywait -m -e close_write -e delete -r $PROTO_SOURCE_DIR \
  | debounce -t $PROTO_COMPILE_DELAY \
  | while read -r file;
do
  if [[ $file =~ \.proto$ ]]; then
    compile
  fi
done
