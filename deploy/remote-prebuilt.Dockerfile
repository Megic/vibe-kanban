# syntax=docker/dockerfile:1.6

ARG APP_NAME=remote

# 编译阶段：使用官方 Rust Alpine 镜像
# 固定使用一个稳定版本，而不是 latest，减少不必要的更新尝试
FROM rust:1.93-alpine AS builder
ARG APP_NAME

# 禁用 rustup 自动更新检查，防止构建时下载
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.93.0
# 设置 Rustup 镜像（使用 RsProxy）
ENV RUSTUP_DIST_SERVER="https://rsproxy.cn"
ENV RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
# 配置 cargo 镜像（使用 RsProxy sparse 协议）
RUN mkdir -p /usr/local/cargo/registry \
    && echo '[source.crates-io]' > /usr/local/cargo/config.toml \
    && echo 'replace-with = "rsproxy-sparse"' >> /usr/local/cargo/config.toml \
    && echo '[source.rsproxy]' >> /usr/local/cargo/config.toml \
    && echo 'registry = "https://rsproxy.cn/crates.io-index"' >> /usr/local/cargo/config.toml \
    && echo '[source.rsproxy-sparse]' >> /usr/local/cargo/config.toml \
    && echo 'registry = "sparse+https://rsproxy.cn/index/"' >> /usr/local/cargo/config.toml \
    && echo '[registries.rsproxy]' >> /usr/local/cargo/config.toml \
    && echo 'index = "https://rsproxy.cn/crates.io-index"' >> /usr/local/cargo/config.toml \
    && echo '[net]' >> /usr/local/cargo/config.toml \
    && echo 'git-fetch-with-cli = true' >> /usr/local/cargo/config.toml
    

# 配置 Alpine 国内源并安装编译依赖
# 注意：在 Alpine 下静态链接 OpenSSL 需要 openssl-libs-static
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk add --no-cache musl-dev pkgconfig openssl-dev openssl-libs-static git


WORKDIR /app

# 复制整个项目源码
# 注意：这里假设构建上下文是项目根目录
COPY . .

# 强制移除 rust-toolchain.toml 文件，防止 cargo 自动触发 rustup 下载其他版本工具链
RUN rm -f rust-toolchain.toml

# 执行编译
# 移除 RUSTFLAGS='-C target-feature=+crt-static'，因为 async-trait 等 proc-macro 在 musl 目标下不支持静态链接生成动态库
# 使用 CARGO_TARGET_DIR 指向挂载的缓存目录，避免构建过程中产生大量临时文件占满容器根文件系统空间
ENV CARGO_TARGET_DIR=/app/target
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release --manifest-path crates/remote/Cargo.toml \
    && cp /app/target/release/${APP_NAME} /app/remote-server

# 运行时阶段
FROM alpine:3.19 AS runtime
ARG APP_NAME

# 配置 Alpine 国内源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    openssl \
    wget \
    git \
    && adduser -D -u 10001 appuser

WORKDIR /srv

# 从 builder 阶段复制编译好的二进制文件
COPY --from=builder /app/remote-server /usr/local/bin/${APP_NAME}
# 前端静态文件仍然从构建上下文复制（假设本地已经编译好了前端）
COPY packages/remote-web/dist /srv/static

USER appuser

ENV SERVER_LISTEN_ADDR=0.0.0.0:8081 \
    RUST_LOG=info

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["wget","--spider","-q","http://127.0.0.1:8081/v1/health"]

ENTRYPOINT ["/usr/local/bin/remote"]
