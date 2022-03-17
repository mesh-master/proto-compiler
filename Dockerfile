#
# This image builds protocol buffers library from source with Go generation support.
#
FROM golang:1.18-alpine3.15 as builder

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

ENV GOBIN=/usr/local/bin
ADD . /app
# Install utilities and export dependencies
RUN set -xe \
    && mkdir -p /export/lib \
    && mkdir -p /export/proto \
    && cd /app && go install ./... \
    && cp /usr/lib/libstdc++* /export/lib/ \
    && cp /usr/lib/libgcc_s* /export/lib/ \
    && cp /app/api/*.proto /export/proto/

# Install protoc-gen-go
RUN set -xe \
    && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

FROM alpine:3.15 as goenv
RUN set -xe \
    && mkdir -p /app/api \
    && mkdir -p /share \
    && apk update \
    && apk add gawk inotify-tools vim

ENV GOROOT=/usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOBIN=/usr/local/bin

COPY --from=builder /usr/local/ /usr/local/
COPY --from=builder /export/lib/ /usr/lib/
COPY --from=builder /export/proto/ /share/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
