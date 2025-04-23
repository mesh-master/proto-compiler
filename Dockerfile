#
# This image builds protocol buffers library from source with Go generation support.
#
FROM golang:1.23.3-bookworm

ARG USER_ID
ARG GROUP_ID

ARG PROTOBUF_VER=28.3
ARG PROTO_ZIP_FILE="protoc-${PROTOBUF_VER}-linux-x86_64.zip"

ENV USER_ID=$USER_ID
ENV GROUP_ID=$GROUP_ID
ENV GOBIN=/usr/bin
ENV TERM=xterm-color
ENV PS1='\e[33;1m\u@goenv-\h: \e[31m\W\e[0m\$ '

# Install protoc
RUN cd /tmp \
    && apt update \
    && apt install -y unzip python3-pip \
    && apt install -y inotify-tools vim gawk \
    && wget https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VER}/${PROTO_ZIP_FILE} \
    && unzip $PROTO_ZIP_FILE \
    && mv include/google /usr/include/ \
    && cp bin/protoc /usr/bin/ \
    && rm -rf include bin readme.txt

RUN cd / \
    && git clone https://github.com/mesh-master/nanopb.git \
    && pip3 install grpcio-tools --break-system-packages

# Install protoc-gen-go
ARG GO_PLUGINS_CACHE_BUSTER
RUN set -e \
    && echo "\nInstalling latest gRPC Go plugins\n" \
    && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && cd /tmp \
    && git clone --depth 1 https://github.com/mesh-master/grpc-go.git \
    && cd /tmp/grpc-go/cmd/protoc-gen-go-grpc \
    && go install ./...

COPY ./scripts/.profile /root
RUN chmod +x /root/.profile

# Install utilities
ADD . /app
RUN set -e \
    && cd /app && go install ./...

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
