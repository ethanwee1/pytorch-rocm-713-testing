# PyTorch ROCm 7.13 Python 3.10 Testing

Testing suite for PyTorch 2.9, 2.10, 2.11 with ROCm 7.13 and Python 3.10 across gfx942, gfx950, and gfx90a architectures.

**Related Issue:** https://github.com/ROCm/frameworks-internal/issues/16351

## Quick Start

### 1. Clone this repo on each test machine

```bash
git clone <this-repo-url>
cd pytorch-rocm-testing
```

### 2. Trigger Docker builds (once, from any machine)

```bash
./trigger_docker_builds.sh
```

This triggers GitHub Actions to build Docker images for all PyTorch versions and architectures.

### 3. Run tests on each machine

```bash
# On gfx942 machine
./pull_and_test_dockers.sh 2.9 gfx942
./pull_and_test_dockers.sh 2.10 gfx942
./pull_and_test_dockers.sh 2.11 gfx942

# On gfx950 machine
./pull_and_test_dockers.sh 2.9 gfx950
./pull_and_test_dockers.sh 2.10 gfx950
./pull_and_test_dockers.sh 2.11 gfx950

# On gfx90a machine
./pull_and_test_dockers.sh 2.9 gfx90a
./pull_and_test_dockers.sh 2.10 gfx90a
./pull_and_test_dockers.sh 2.11 gfx90a
```

### 4. Collect results

Results are saved in `test_results_<version>_<arch>/` directories.

View summary:
```bash
cat test_results_2.9_gfx942/test_summary.md
```

Update the GitHub issue with results from each test run.

## Files

- **trigger_docker_builds.sh** - Trigger GitHub Actions to build Docker images
- **pull_and_test_dockers.sh** - Pull Docker image and run tests (main script)
- **pytorch_test_script.sh** - Alternative: run tests without Docker
- **pytorch_testing_guide.md** - Detailed documentation
- **README.md** - This file

## Test Matrix

| PyTorch | Python | ROCm | Architectures |
|---------|--------|------|---------------|
| 2.9, 2.10, 2.11 | 3.10 | 7.13 | gfx942, gfx950, gfx90a |

## What Gets Tested

Each test run executes:
1. **ResNet50 micro-benchmark** from https://github.com/ROCm/pytorch-micro-benchmarking
2. **Default PyTorch tests**: test_nn, test_torch, test_cuda, test_ops, test_autograd, inductor tests
3. **Distributed tests**: test_c10d_common, test_c10d_nccl, test_distributed_spawn

With environment:
- `CI=1`
- `PYTORCH_TEST_WITH_ROCM=1`
- `HSA_FORCE_FINE_GRAIN_PCIE=1`
- `PYTORCH_TESTING_DEVICE_ONLY_FOR="cuda"`

## Requirements

- Docker installed on each test machine
- ROCm-capable GPU (gfx942, gfx950, or gfx90a)
- GitHub CLI (`gh`) for triggering builds
- Access to ROCm/pytorch repository

For more details, see [pytorch_testing_guide.md](pytorch_testing_guide.md)
