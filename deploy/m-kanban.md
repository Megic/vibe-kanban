##打包server
DOCKER_BUILDKIT=1 docker build --memory=4g --memory-swap=4g -f crates/remote/Dockerfile -t vibe-remote:dev .

## 1. 编译前端（Windows 环境）
```powershell
# 在 packages/remote-web 目录下
cd packages/remote-web
pnpm build
cd ../..
```

## 2. 构建镜像（包含后端编译）
前端文件需要先在本地编译（见上一步），但后端 Rust 代码会直接在 Docker 镜像构建过程中编译（基于 `rust:alpine` 镜像）。

这样避免了 Windows 本地交叉编译的复杂性和挂载路径问题。

执行以下命令：
```bash
DOCKER_BUILDKIT=1 docker build -f deploy/remote-prebuilt.Dockerfile -t vibe-remote:dev .
```

> 说明：
> 1. 这个 Dockerfile 会使用多阶段构建：先在 `rust:alpine` 中编译 Rust 后端，再将二进制文件复制到最终的 Alpine 运行时镜像。
> 2. 前端静态文件 (`packages/remote-web/dist`) 仍然是从你本地复制进去的，所以请确保第一步前端编译已完成。


export VK_SHARED_API_BASE=https://ai-code.cloudsean.com pnpm run dev

pnpm install
pnpm run dev