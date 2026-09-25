# mcl-bookclub
#
# A book club kept as a reckon-db event store, with projections into sqlite, on
# the macula mesh through mcl_om. The teaching service.
#
# TWO DATA DIRECTORIES ON THE /data VOLUME, declared by the code that writes
# them: the reckon-db store at /data/mcl_bookclub_store and the sqlite read
# model at /data/bookclub.sqlite3. Without the mount every recreate forgets the
# club's whole record.

# ⚠ THE RUNTIME IS PINNED IN TWO PLACES AND THEY MUST AGREE: here and `lint.yml'
# beside it. A generated service that builds on one release and tests on another
# only ever proves "the tests pass on the CI release". The generated suite
# (mcl_bookclub_service_tests) compares the pins in both files, .tool-versions
# and the running VM, and fails when they drift.
#
# ⚠ PINNED BY TAG AND DIGEST. `erlang:28-alpine' floats; a re-pushed tag must
# not change what builds. hexpm's image, because Docker's own `erlang'
# publishes no 28.4.3; Alpine 3.22.6, the same release as the runtime stage
# below, whose OpenSSL 3.5 carries ML-DSA. Move both on purpose, never by drift.
FROM docker.io/hexpm/erlang:28.4.3-alpine-3.22.6@sha256:3815b99f486c2509baf556045bca0c5fc1c3ee50fb50a80590534f22cb48736c AS builder
WORKDIR /build

# macula ships a QUIC NIF. MACULA_FORCE_SOURCE_BUILD makes it build here rather
# than fetch a prebuilt binary linked against a different libc, which is the
# recorded glibc trap: the fetched artifact loads on the build host and fails on
# alpine at runtime.
RUN apk add --no-cache git curl bash build-base cmake perl linux-headers \
        openssl-dev zstd-dev snappy-dev lz4-dev sqlite-dev
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV MACULA_FORCE_SOURCE_BUILD=1

# rebar3 pinned to a release and its sha256, the same one lint.yml installs.
RUN curl -fsSL https://github.com/erlang/rebar3/releases/download/3.27.0/rebar3 \
        -o /usr/local/bin/rebar3 \
    && echo "af85aab41f9fd74bdd6341ebdf6fe9c88077aab9f8eac82371583fa02f2b0bdf  /usr/local/bin/rebar3" \
        | sha256sum -c - \
    && chmod +x /usr/local/bin/rebar3

# Dependencies resolve from rebar.config alone, so this layer survives every
# change to config/ and apps/ and the Rust toolchain is not re-run per commit.
COPY rebar.config ./
RUN rebar3 get-deps

COPY config ./config
COPY apps ./apps
RUN rebar3 as prod release

# ⚠ PINNED BY RELEASE AND DIGEST, like the builder. The same Alpine release as
# the builder, whose ERTS and NIFs this runs; the generated runtime guard
# refuses the two drifting apart.
FROM docker.io/alpine:3.22.6@sha256:5291449c3df73caf6ed85e649dec1b9e818b39a5d8c871e97afc13e9cd5e8fa8
# LINKS THE PACKAGE TO THE REPOSITORY. On registries that read it, ghcr among
# them, a package without this label is an orphan.
LABEL org.opencontainers.image.source="https://github.com/macula-services/mcl-bookclub"
# The commit this image was built from (build-push passes github.sha).
ARG REVISION=unknown
LABEL org.opencontainers.image.revision="${REVISION}"
# sqlite-libs: the RUNTIME library for esqlite's NIF, compiled against in the
# builder stage above via sqlite-dev.
RUN apk add --no-cache ncurses-libs libstdc++ libgcc openssl ca-certificates curl \
        zstd-libs snappy lz4-libs sqlite-libs
WORKDIR /app
COPY --from=builder /build/_build/prod/rel/mcl_bookclub ./

ENV HOME=/app
ENV RELX_REPLACE_OS_VARS=true

ENV MCL_NODE_NAME=mcl_bookclub
ENV MCL_NODE_HOST=127.0.0.1
ENV MCL_COOKIE=mcl_bookclub
ENV MCL_HEALTH_PORT=8484
# The reckon-db store and the sqlite read model. A named volume or a bind mount
# on a bulk drive; without one every recreate forgets the club's record.
ENV MCL_DATA_DIR=/data

VOLUME ["/etc/mcl/secrets", "/data"]

EXPOSE 8484
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${MCL_HEALTH_PORT}/health" || exit 1

CMD ["/app/bin/mcl_bookclub", "foreground"]
