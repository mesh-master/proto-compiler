#
# This image builds protocol buffers library from source with Go generation support.
#
FROM golang:1.18rc1-alpine3.15 as builder

ARG PROTOBUF_VER

# System setup
RUN apk update && apk add \
    git \
    curl \
    build-base \
    autoconf \
    automake \
    libtool

# Install protoc
ENV PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOBUF_VER/protobuf-cpp-$PROTOBUF_VER.tar.gz"
RUN curl -L -o /tmp/protobuf.tar.gz $PROTOBUF_URL
RUN set -xe \
    && cd /tmp/ \
    && tar xvzf protobuf.tar.gz \
    && cd "/tmp/protobuf-$PROTOBUF_VER" \
    && ./autogen.sh \
    && ./configure --prefix=/usr/local \
    && make -j 3 \
    && make check \
    && make install

# Install protoc-gen-go
ENV GOBIN=/usr/local/bin
RUN set -ex \
    && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

ADD . /app
RUN mkdir -p /app/api
RUN cd /app && go install ./...

FROM alpine:3.14
RUN set -xe \
    && apk update \
    && apk add gawk inotify-tools vim

ENV GOROOT=/usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

COPY --from=builder /usr/local/ /usr/local/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
