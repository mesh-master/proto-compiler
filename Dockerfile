#
# This image builds protocol buffers library from source with Go generation support.
#
FROM golang:1.20.4-buster as builder

ARG USER_ID
ARG GROUP_ID

ENV USER_ID=$USER_ID
ENV GROUP_ID=$GROUP_ID
ENV GOBIN=/usr/bin
ENV TERM=xterm-color
ENV PS1='\e[33;1m\u@goenv-\h: \e[31m\W\e[0m\$ '

# Install utilities
ADD . /app
RUN set -e \
    && cd /app && go install ./...

# Install protoc
RUN set -e \
    && apt update \
    && apt install curl gnupg \
    &&  curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor -o /usr/share/keyrings/bazel-archive-keyring.gpg \
    &&  echo "deb [signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" |  tee /etc/apt/sources.list.d/bazel.list >/dev/null \
    &&  apt update \
    &&  apt-get install g++ git bazel \
    &&  cd /tmp && git clone https://github.com/protocolbuffers/protobuf.git \
    &&  cd protobuf \
    &&  git submodule update --init --recursive \
    &&  bazel build :protoc :protobuf \
    &&  cp bazel-bin/protoc /usr/bin/

# Install protoc-gen-go
RUN set -e \
    && go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && cd /tmp \
    && git clone --depth 1 https://github.com/go-serv/grpc-go \
    && cd /tmp/grpc-go/cmd/protoc-gen-go-grpc \
    && go install ./...

#ENV GOROOT=/usr/go

COPY ./scripts/.profile /root
RUN chmod +x /root/.profile

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

SHELL ["/bin/bash", "-ec"]
ENTRYPOINT ["/entrypoint.sh"]
