# PyTorch ROCm 7.13 Python 3.10 Testing Guide

## Workflow Overview

1. **Trigger Docker builds** (once, from any machine)
2. **Pull Docker images and run tests** (on each target machine)
3. **Collect results** and update GitHub issue

## Step 1: Trigger Docker Builds

**Run once to build all Docker images:**

```bash
./trigger_docker_builds.sh
```

This will trigger GitHub Actions to build Docker images for:
- PyTorch 2.9, 2.10, 2.11
- Python 3.10
- ROCm 7.13 from https://rocm.prereleases.amd.com/
- GFX architectures: gfx950-dcgpu, gfx94X-dcgpu, gfx90X-dcgpu

**Monitor build progress:**
```bash
# List recent workflow runs
gh run list --repo ROCm/pytorch --workflow build_portable_linux_pytorch_dockers.yml --limit 20

# Watch a specific run
gh run watch <run-id> --repo ROCm/pytorch
```

## Step 2: Pull Docker Images and Run Tests

**On each machine with the target GFX architecture:**

```bash
# On gfx942 machine - test all PyTorch versions
./pull_and_test_dockers.sh 2.9 gfx942
./pull_and_test_dockers.sh 2.10 gfx942
./pull_and_test_dockers.sh 2.11 gfx942

# On gfx950 machine - test all PyTorch versions
./pull_and_test_dockers.sh 2.9 gfx950
./pull_and_test_dockers.sh 2.10 gfx950
./pull_and_test_dockers.sh 2.11 gfx950

# On gfx90a machine - test all PyTorch versions
./pull_and_test_dockers.sh 2.9 gfx90a
./pull_and_test_dockers.sh 2.10 gfx90a
./pull_and_test_dockers.sh 2.11 gfx90a
```

## Step 3: Collect Results

After running tests on each machine, results are saved in directories like:
- `test_results_2.9_gfx942/`
- `test_results_2.10_gfx950/`
- etc.

**View summary:**
```bash
cat test_results_<version>_<arch>/test_summary.md
```

**Extract errors:**
```bash
grep -A 5 "FAILED\|ERROR" test_results_<version>_<arch>/defaulttest.log
grep -A 5 "FAILED\|ERROR" test_results_<version>_<arch>/disttest.log
```

**Update GitHub issue:** Copy the contents and paste into the appropriate expandable section at:
https://github.com/ROCm/frameworks-internal/issues/16351

## What the pull_and_test_dockers.sh script does:

1. **Sets environment variables:**
   - `CI=1`
   - `PYTORCH_TEST_WITH_ROCM=1`
   - `HSA_FORCE_FINE_GRAIN_PCIE=1`
   - `PYTORCH_TESTING_DEVICE_ONLY_FOR="cuda"`

2. **Runs micro-benchmark:**
   - Clones https://github.com/ROCm/pytorch-micro-benchmarking
   - Executes: `python3 micro_benchmarking_pytorch.py --network resnet50`

3. **Runs PyTorch tests:**
   - Installs requirements from `.ci/docker/requirements-ci.txt`
   - Default config: `test_nn`, `test_torch`, `test_cuda`, `test_ops`, etc.
   - Distributed config: `distributed/test_c10d_common`, `test_c10d_nccl`, etc.

4. **Generates output files:**
   - `microbench_<version>_<arch>.log`
   - `defaulttest_<version>_<arch>.log`
   - `disttest_<version>_<arch>.log`
   - `test_summary_<version>_<arch>.md`

## Test Matrix

| PyTorch | Python | ROCm | Architecture |
|---------|--------|------|--------------|
| 2.9     | 3.10   | 7.13 | gfx942       |
| 2.9     | 3.10   | 7.13 | gfx950       |
| 2.9     | 3.10   | 7.13 | gfx90a       |
| 2.10    | 3.10   | 7.13 | gfx942       |
| 2.10    | 3.10   | 7.13 | gfx950       |
| 2.10    | 3.10   | 7.13 | gfx90a       |
| 2.11    | 3.10   | 7.13 | gfx942       |
| 2.11    | 3.10   | 7.13 | gfx950       |
| 2.11    | 3.10   | 7.13 | gfx90a       |

## Collecting Results

After running tests, collect the summary file and paste into GitHub issue #16351:
```bash
cat test_summary_<version>_<arch>.md
```

Or view detailed logs:
```bash
# Micro-benchmark details
cat microbench_<version>_<arch>.log

# Default test errors
grep -A 5 "FAILED\|ERROR" defaulttest_<version>_<arch>.log

# Distributed test errors
grep -A 5 "FAILED\|ERROR" disttest_<version>_<arch>.log
```

## Docker Setup Example

If using Docker from https://rocm.prereleases.amd.com/:

```bash
# Pull or build docker with ROCm 7.13 prerelease and Python 3.10
docker run -it --device=/dev/kfd --device=/dev/dri \
  --group-add video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  -v $PWD:/workspace \
  <rocm-7.13-pytorch-image> /bin/bash

# Inside container
cd /workspace
./pytorch_test_script.sh 2.9 gfx942
```

## GitHub Issue Tracking

Update results in: https://github.com/ROCm/frameworks-internal/issues/16351

Paste results into the appropriate expandable section for each PyTorch version and architecture.
