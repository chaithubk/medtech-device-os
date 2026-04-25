# MedTech Device OS

Embedded Linux operating system for medical IoT devices using Yocto Project.

## Stage 1: QEMU Emulation

### Features
- ✅ Yocto/Poky build system
- ✅ Minimal core image
- ✅ QEMU ARM64 emulator
- ✅ MQTT client support
- ✅ Python 3 runtime
- ✅ SSH server
- ✅ SBOM generation
- ✅ Docker-based build environment

### Architecture

```
Development (Docker Container)
│
├── Yocto/Bitbake
│   ├── Poky layers
│   └── meta-medtech (custom recipes)
│
└── Build artifacts
	├── core-image-minimal
	├── kernel
	├── rootfs
	└── SBOM
		↓
QEMU Emulator
├── Boot Linux
├── Run services
└── Test integration
```

### Quick Start

#### Build in Dev Container

```bash
# Reopen folder in container
# Cmd+Shift+P → Dev Containers: Reopen in Container

# Initialize Yocto
source yocto/poky/oe-init-build-env yocto/build
cp ../conf/local.conf.sample conf/local.conf
cp ../conf/bblayers.conf.sample conf/bblayers.conf

# Build image (takes 30-45 minutes first build)
bitbake core-image-minimal
```

### Boot in QEMU

```
# From yocto/build directory
runqemu qemuarm64 core-image-minimal nographic

# Inside QEMU:
# Login: root (no password)
# Check network: ip addr
# Exit QEMU: Ctrl+A then X
```

### Generate SBOM

```
bash scripts/generate-sbom.sh
# Outputs: sbom/sbom.json
```

### Testing

```
# Run tests in QEMU
pytest tests/device/ -v

# Test MQTT
mosquitto_sub -t "medtech/#" &
mosquitto_pub -t "test" -m "hello"

# SSH into QEMU
ssh -p 2222 root@localhost
```