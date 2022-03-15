#!/usr/bin/env sh

# set -x

new_line=\\\\n
proto_compiled_mounted_dir=/app/proto-compiled

_done() {
  echo -e '\tdone\n'
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
  echo -n $(sed -i -r "/^\s*package\s+[^;]+;/a${new_line}option go_package = \"$PROTOBUF_GO_IMPORT_PREFIX/$go_path_postfix\";" $file)
}

compile_proto() {
  local proto_dir=/tmp/proto-$(date +%s)
  local proto_out=/tmp/proto-compiled-$(date +%s)

  mkdir -p $proto_dir
  mkdir -p $proto_out
  cp -r /app/api/* $proto_dir/
  cp /app/extension.proto $proto_dir

  find $proto_dir -name '*.proto' -type f | while read file;
    do
      echo "Auto-generating go_option for $(basename $file)..."
      autogen_go_package_option $file
    done
  _done

  find $proto_dir -name '*.proto' -type f | while read file;
    do
      echo "Compiling $(basename $file)..."
      protoc -I"$proto_dir" \
        --go_opt=paths=source_relative \
        --go-grpc_opt=paths=source_relative \
        --go_out=$proto_out \
        --go-grpc_out=$proto_out \
        $file
    done
  _done

  cp -r $proto_out/* $proto_compiled_mounted_dir/
  chown -R $USER_ID:$GROUP_ID $proto_compiled_mounted_dir
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

inotifywait -m -e modify -e delete -r --include='.proto$' /app/api | debounce -t 10000 | while read;
do
  compile_proto
done
