# -----------------------------------
# Build hfmt
# -----------------------------------

FROM debian:stretch-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG REVISION=master

ENV YQ_VERSION=3.3.2
ENV UPX_VERSION=3.94

RUN apt-get update \
 && apt-get install --no-install-recommends -y \
    build-essential \
    libffi-dev \
    libgmp-dev \
    zlib1g-dev \
    curl \
    ca-certificates \
    git \
 && curl -sSL https://get.haskellstack.org/ | sh \
 && rm -rf /var/lib/apt/lists/*

# Install tool for yaml file merge
RUN curl -sSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# FIX https://bugs.launchpad.net/ubuntu/+source/gcc-4.4/+bug/640734
WORKDIR /usr/lib/gcc/x86_64-linux-gnu/6/
RUN cp crtbeginT.o crtbeginT.o.orig
RUN cp crtbeginS.o crtbeginT.o

WORKDIR /opt/hfmt/

RUN git clone --branch=${REVISION} https://github.com/danstiner/hfmt.git .

RUN git status

COPY package.static.yaml ./

# Remove cabal file, we need only package.yaml
# Overwrite original options in case of static build
RUN rm hfmt.cabal && \
    yq merge --inplace package.yaml package.static.yaml \
    && cat package.yaml

RUN stack install

# Check, what executable linked static
RUN ldd /root/.local/bin/hfmt || true

# Compress binary with UPX
RUN curl -sSL https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-amd64_linux.tar.xz \
  | tar -x --xz --strip-components 1 upx-${UPX_VERSION}-amd64_linux/upx \
  && ./upx --best --ultra-brute /root/.local/bin/hfmt

# Binary rely on config file and fail with error:
#
# hfmt: user error (Failed to find requested hint files:
#   /usr/local/bin/data/hlint.yaml
# )
#
# Workaround from https://github.com/haskell/haskell-ide-engine/issues/872#issuecomment-470293891
RUN touch /root/.local/bin/hlint.yaml

# -----------------------------------
# Create distro
# -----------------------------------

FROM scratch AS distro

ENV LC_ALL=C.UTF-8

# Copy the executable from the builder stage
COPY --from=builder /root/.local/bin/hfmt /usr/local/bin/
COPY --from=builder /root/.local/bin/hlint.yaml /usr/local/bin/data/

ENTRYPOINT ["/usr/local/bin/hfmt"]
CMD ["--version"]