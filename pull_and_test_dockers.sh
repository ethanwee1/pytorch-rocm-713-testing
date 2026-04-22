#!/bin/bash
# Pull Docker images and run tests for PyTorch with ROCm 7.13
# Usage: ./pull_and_test_dockers.sh <pytorch_version> <gfx_arch>
# Example: ./pull_and_test_dockers.sh 2.9 gfx942

set -e

PYTORCH_VERSION=${1:-"2.9"}
GFX_ARCH=${2:-"gfx942"}  # Actual GPU architecture on this machine
PYTHON_VERSION="3.10"

# Map GPU arch to Docker image family
case "${GFX_ARCH}" in
    gfx942)
        GFX_FAMILY="gfx94X-dcgpu"
        ;;
    gfx950)
        GFX_FAMILY="gfx950-dcgpu"
        ;;
    gfx90a)
        GFX_FAMILY="gfx90X-dcgpu"
        ;;
    *)
        echo "Unknown GFX architecture: ${GFX_ARCH}"
        echo "Supported: gfx942, gfx950, gfx90a"
        exit 1
        ;;
esac

# Docker image details (adjust based on actual registry and naming)
DOCKER_REGISTRY="docker.io"
DOCKER_IMAGE="rocm/pytorch-private"
# Image tag format might be something like: 2.9-rocm7.13-py3.10-gfx94X-dcgpu
# The workflow auto-discovers ROCm version, so tag won't include specific version
# We'll need to check what tag format the workflow actually uses
ROCM_VERSION="7.13"  # Using nightlies with auto-discovered version
DOCKER_TAG="${PYTORCH_VERSION}-rocm${ROCM_VERSION}-py${PYTHON_VERSION}-${GFX_FAMILY}"

echo "=========================================="
echo "PyTorch Docker Test Setup"
echo "=========================================="
echo "PyTorch Version: ${PYTORCH_VERSION}"
echo "GFX Architecture: ${GFX_ARCH} (${GFX_FAMILY})"
echo "Python Version: ${PYTHON_VERSION}"
echo "Docker Image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
echo "=========================================="
echo ""

# Pull the Docker image
echo "Pulling Docker image..."
docker pull ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}

if [ $? -ne 0 ]; then
    echo ""
    echo "Failed to pull image. Checking available tags..."
    echo "You may need to adjust the DOCKER_TAG format in this script."
    echo ""
    echo "Try: docker search ${DOCKER_IMAGE}"
    exit 1
fi

# Create output directory for logs
OUTPUT_DIR="./test_results_${PYTORCH_VERSION}_${GFX_ARCH}"
mkdir -p ${OUTPUT_DIR}

echo ""
echo "Running tests in Docker container..."
echo "Output directory: ${OUTPUT_DIR}"
echo ""

# Run the tests inside Docker container
docker run -it --rm \
    --device=/dev/kfd \
    --device=/dev/dri \
    --group-add video \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    -v ${PWD}/${OUTPUT_DIR}:/output \
    -e CI=1 \
    -e PYTORCH_TEST_WITH_ROCM=1 \
    -e HSA_FORCE_FINE_GRAIN_PCIE=1 \
    -e PYTORCH_TESTING_DEVICE_ONLY_FOR="cuda" \
    ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
    /bin/bash -c "
        set -e
        cd /opt/pytorch || cd /workspace/pytorch || cd ~

        echo '=========================================='
        echo 'Environment Setup'
        echo '=========================================='
        python3 --version
        pip3 list | grep torch
        rocm-smi --showproductname || true
        echo ''

        # Clone pytorch-micro-benchmarking
        echo '=========================================='
        echo 'Cloning pytorch-micro-benchmarking'
        echo '=========================================='
        if [ ! -d pytorch-micro-benchmarking ]; then
            git clone https://github.com/ROCm/pytorch-micro-benchmarking
        fi

        # Run micro-benchmark
        echo ''
        echo '=========================================='
        echo 'Running ResNet50 Micro-Benchmark'
        echo '=========================================='
        cd pytorch-micro-benchmarking
        python3 micro_benchmarking_pytorch.py --network resnet50 2>&1 | tee /output/microbench.log
        cd ..

        # Install test requirements
        echo ''
        echo '=========================================='
        echo 'Installing test requirements'
        echo '=========================================='
        if [ -f .ci/docker/requirements-ci.txt ]; then
            pip3 install -r .ci/docker/requirements-ci.txt
        else
            echo 'Warning: requirements-ci.txt not found, skipping'
        fi

        # Run default test config
        echo ''
        echo '=========================================='
        echo 'Running DEFAULT test config'
        echo '=========================================='
        TEST_CONFIG=default HIP_VISIBLE_DEVICES=0 python3 test/run_test.py \
            --continue-through-error \
            -i test_nn test_torch test_cuda test_ops test_unary_ufuncs test_binary_ufuncs test_autograd inductor/test_torchinductor \
            -v 2>&1 | tee /output/defaulttest.log

        # Run distributed test config
        echo ''
        echo '=========================================='
        echo 'Running DISTRIBUTED test config'
        echo '=========================================='
        TEST_CONFIG=distributed HIP_VISIBLE_DEVICES=0,1 python3 test/run_test.py \
            --continue-through-error \
            -i distributed/test_c10d_common distributed/test_c10d_nccl distributed/test_distributed_spawn \
            -v 2>&1 | tee /output/disttest.log

        echo ''
        echo '=========================================='
        echo 'All tests complete!'
        echo '=========================================='
    "

# Generate summary
echo ""
echo "Generating test summary..."

cat > ${OUTPUT_DIR}/test_summary.md <<EOF
# PyTorch ${PYTORCH_VERSION} Test Results - ${GFX_ARCH}

**ROCm Version:** ${ROCM_VERSION}
**Python Version:** ${PYTHON_VERSION}
**GFX Architecture:** ${GFX_ARCH}
**Docker Image:** ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}
**Date:** $(date)

## Micro-Benchmark Results (ResNet50)
\`\`\`
$(tail -50 ${OUTPUT_DIR}/microbench.log 2>/dev/null || echo "No micro-benchmark results found")
\`\`\`

## Default Test Config Results
\`\`\`
$(grep -E "FAILED|PASSED|ERROR|Ran [0-9]+ test" ${OUTPUT_DIR}/defaulttest.log 2>/dev/null | tail -20 || echo "No default test results found")
\`\`\`

## Distributed Test Config Results
\`\`\`
$(grep -E "FAILED|PASSED|ERROR|Ran [0-9]+ test" ${OUTPUT_DIR}/disttest.log 2>/dev/null | tail -20 || echo "No distributed test results found")
\`\`\`

## Full Logs
- Micro-benchmark: ${OUTPUT_DIR}/microbench.log
- Default tests: ${OUTPUT_DIR}/defaulttest.log
- Distributed tests: ${OUTPUT_DIR}/disttest.log
EOF

echo ""
echo "=========================================="
echo "Testing Complete!"
echo "=========================================="
echo "Results saved to: ${OUTPUT_DIR}/"
echo "Summary: ${OUTPUT_DIR}/test_summary.md"
echo ""
echo "To view summary:"
echo "  cat ${OUTPUT_DIR}/test_summary.md"
echo ""
echo "To extract errors:"
echo "  grep -A 5 'FAILED\\|ERROR' ${OUTPUT_DIR}/defaulttest.log"
echo "  grep -A 5 'FAILED\\|ERROR' ${OUTPUT_DIR}/disttest.log"
