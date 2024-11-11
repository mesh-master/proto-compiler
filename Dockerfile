#
# This image builds protocol buffers library from source with Go generation support.
#
FROM golang:1.23.3-bookworm as builder

ARG USER_ID
ARG GROUP_ID

ARG PROTO_ZIP_FILE="protoc-28.3-linux-x86_64.zip"

ENV USER_ID=$USER_ID
ENV GROUP_ID=$GROUP_ID
ENV GOBIN=/usr/bin
ENV TERM=xterm-color
ENV PS1='\e[33;1m\u@goenv-\h: \e[31m\W\e[0m\$ '

# Install protoc
RUN cd /tmp \
    && apt update \
    && apt install -y unzip python3-pip python3.11-venv \
    && apt install -y inotify-tools vim gawk \
    && wget https://github.com/protocolbuffers/protobuf/releases/download/v28.3/$PROTO_ZIP_FILE \
    && unzip $PROTO_ZIP_FILE \
    && cp -r include/ /usr/include/ \
    && cp bin/protoc /usr/bin/ \
    && rm -rf include bin readme.txt

RUN cd / \
    && git clone https://github.com/mesh-master/nanopb.git \
    && python3 -m venv /nanopb \
    && . /nanopb/bin/activate \
    && pip3 install grpcio-tools

# Install protoc-gen-go
RUN set -e \
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
