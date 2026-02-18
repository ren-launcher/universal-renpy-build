# Universal Ren'Py Build

从源码构建 [Ren'Py](https://github.com/renpy/renpy) RAPT（Android Packaging Tool），支持 **16K page alignment**（Google Play 要求）。基于上游 [renpy-build](https://github.com/renpy/renpy-build) 封装，通过 patch 方式管理所有修改。

## 特性

- **16K page alignment** — Android `.so` 使用 `max-page-size=16384`，符合 Google Play 要求
- **3 ABIs** — arm64-v8a, armeabi-v7a, x86_64
- **官方打包** — 使用 Ren'Py 自带的 `distribute.py` 生成 RAPT DLC zip
- **CI 就绪** — GitHub Actions 工作流，push tag 自动构建并发布到 Release

## 项目结构

```
config.env                      ← 版本配置（修改此文件切换 Ren'Py 版本）
Makefile                        ← 构建入口
scripts/
    prepare-linux.sh            ← 系统依赖安装（全平台）
    download-tars.sh            ← 下载源码 tarball
    distribute.sh               ← 打包完整 SDK + DLC
    distribute-rapt.sh          ← 仅打包 RAPT DLC
    check-env.sh                ← 检查构建依赖
patches/
    renpy-build/                ← renpy-build 补丁
    renpy/                      ← renpy 引擎补丁
    pygame_sdl2/                ← pygame_sdl2 补丁
stubs/
    Live2DCubismCore.h          ← Live2D 头文件 stub
work/                           ← 构建工作区（git-ignored）
output/                         ← 最终产物
```

## 快速开始 — 构建 RAPT

### 系统依赖（Ubuntu 22.04）

```bash
sudo apt-get install -y \
    git build-essential ccache curl unzip autoconf \
    python-dev-is-python2 python3-dev python3-jinja2 \
    libssl-dev libbz2-dev
```

### 构建 & 打包

```bash
make clone        # 克隆 renpy-build、renpy、pygame_sdl2
make patch        # 应用补丁
make tars-android # 下载源码 tarball（仅 Android 所需）
make rapt         # 构建 Android 三个 ABI
make dist-rapt    # 使用官方工具打包 RAPT DLC

ls output/        # renpy-<VERSION>-rapt.zip
```

### CI / GitHub Actions

推送 tag 自动触发构建并发布到 Release：

```bash
git tag v<VERSION>
git push origin v<VERSION>
```

也可在 Actions 页面手动触发（workflow_dispatch）。

## 版本配置

所有版本信息集中在 `config.env`：

```env
RENPY_VERSION   = x.y.z
RENPY_TAG       = x.y.z.NNNN
RENPY_BUILD_TAG = renpy-x.y.z.NNNN
PYGAME_SDL2_TAG = renpy-x.y.z.NNNN
```

修改后重新执行 `make clone patch tars-android rapt dist-rapt` 即可构建其他版本。

## 补丁说明

| 补丁 | 说明 |
|------|------|
| `renpy-build/0001-android-16k-page-alignment.patch` | Android LDFLAGS 添加 `-Wl,-z,max-page-size=16384` |
| `renpy-build/0002-fix-build-issues.patch` | copytree Python 3.10 兼容、SDL2 Wayland 修复、armv7l sysroot 修复 |
| `renpy/0001-distribute-allow-env-override-git-describe.patch` | 支持 `RENPY_GIT_DESCRIBE` 环境变量覆盖（浅克隆兼容） |

### 创建补丁

```bash
cd work/renpy-build
# 修改代码...
git diff > ../../patches/renpy-build/0003-description.patch
```

补丁按文件名字母序应用，使用数字前缀控制顺序。

## 全平台构建

如需构建所有平台（Linux、Windows、macOS、Android、iOS）：

```bash
sudo ./scripts/prepare-linux.sh
make check-env
make all
```

## 所有 Make 目标

| 目标 | 说明 |
|------|------|
| `make clone` | 克隆源码仓库 |
| `make patch` | 应用补丁 |
| `make tars-android` | 下载 tarball（仅 Android） |
| `make tars` | 下载全部 tarball |
| `make rapt` | 构建 RAPT（Android） |
| `make dist-rapt` | 打包 RAPT DLC |
| `make build` | 构建所有平台 |
| `make dist` | 打包完整 SDK + DLC |
| `make clean` | 清理所有内容 |
| `make clean-build` | 清理构建产物（保留源码） |

## License

本项目封装上游 [renpy-build](https://github.com/renpy/renpy-build)，遵循 Ren'Py 的许可条款。
