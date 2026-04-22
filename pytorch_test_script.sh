#!/bin/bash
# PyTorch ROCm 7.13 Python 3.10 Testing Script
# Usage: ./pytorch_test_script.sh <pytorch_version> <gfx_arch>
# Example: ./pytorch_test_script.sh 2.9 gfx942

PYTORCH_VERSION=${1:-"2.9"}
GFX_ARCH=${2:-"gfx942"}
ROCM_VERSION="7.13"
PYTHON_VERSION="3.10"

echo "=========================================="
echo "PyTorch ${PYTORCH_VERSION} Testing on ${GFX_ARCH}"
echo "ROCm ${ROCM_VERSION} | Python ${PYTHON_VERSION}"
echo "=========================================="

# Export required environment variables
export CI=1
export PYTORCH_TEST_WITH_ROCM=1
export HSA_FORCE_FINE_GRAIN_PCIE=1
export PYTORCH_TESTING_DEVICE_ONLY_FOR="cuda"

# Setup PyTorch environment (adjust based on your docker/installation method)
# If using docker from https://rocm.prereleases.amd.com/
echo "Setting up environment..."

# Clone pytorch-micro-benchmarking if not already present
if [ ! -d "pytorch-micro-benchmarking" ]; then
    echo "Cloning pytorch-micro-benchmarking..."
    git clone https://github.com/ROCm/pytorch-micro-benchmarking
fi

# Run micro-benchmark
echo ""
echo "=========================================="
echo "Running ResNet50 Micro-Benchmark"
echo "=========================================="
cd pytorch-micro-benchmarking
python3 micro_benchmarking_pytorch.py --network resnet50 2>&1 | tee ../microbench_${PYTORCH_VERSION}_${GFX_ARCH}.log
cd ..

# Assume we're in pytorch directory for tests
# If not, clone or navigate to pytorch repo
echo ""
echo "=========================================="
echo "Installing test requirements"
echo "=========================================="
pip3 install -r .ci/docker/requirements-ci.txt

# Run default test config
echo ""
echo "=========================================="
echo "Running DEFAULT test config"
echo "=========================================="
TEST_CONFIG=default HIP_VISIBLE_DEVICES=0 python3 test/run_test.py --continue-through-error -i test_nn test_torch test_cuda test_ops test_unary_ufuncs test_binary_ufuncs test_autograd inductor/test_torchinductor -v 2>&1 | tee defaulttest_${PYTORCH_VERSION}_${GFX_ARCH}.log

# Run distributed test config
echo ""
echo "=========================================="
echo "Running DISTRIBUTED test config"
echo "=========================================="
TEST_CONFIG=distributed HIP_VISIBLE_DEVICES=0,1 python3 test/run_test.py --continue-through-error -i distributed/test_c10d_common distributed/test_c10d_nccl distributed/test_distributed_spawn -v 2>&1 | tee disttest_${PYTORCH_VERSION}_${GFX_ARCH}.log

echo ""
echo "=========================================="
echo "Testing complete!"
echo "=========================================="
echo "Results saved to:"
echo "  - microbench_${PYTORCH_VERSION}_${GFX_ARCH}.log"
echo "  - defaulttest_${PYTORCH_VERSION}_${GFX_ARCH}.log"
echo "  - disttest_${PYTORCH_VERSION}_${GFX_ARCH}.log"
echo ""
echo "Generating summary..."
echo ""

# Generate summary
cat > test_summary_${PYTORCH_VERSION}_${GFX_ARCH}.md <<EOF
# PyTorch ${PYTORCH_VERSION} Test Results - ${GFX_ARCH}

**ROCm Version:** ${ROCM_VERSION}
**Python Version:** ${PYTHON_VERSION}
**GFX Architecture:** ${GFX_ARCH}
**Date:** $(date)

## Micro-Benchmark Results (ResNet50)
\`\`\`
$(tail -50 microbench_${PYTORCH_VERSION}_${GFX_ARCH}.log)
\`\`\`

## Default Test Config Results
\`\`\`
$(grep -E "FAILED|PASSED|ERROR|Ran [0-9]+ test" defaulttest_${PYTORCH_VERSION}_${GFX_ARCH}.log | tail -20)
\`\`\`

## Distributed Test Config Results
\`\`\`
$(grep -E "FAILED|PASSED|ERROR|Ran [0-9]+ test" disttest_${PYTORCH_VERSION}_${GFX_ARCH}.log | tail -20)
\`\`\`

## Full Logs
- Micro-benchmark: microbench_${PYTORCH_VERSION}_${GFX_ARCH}.log
- Default tests: defaulttest_${PYTORCH_VERSION}_${GFX_ARCH}.log
- Distributed tests: disttest_${PYTORCH_VERSION}_${GFX_ARCH}.log
EOF

echo "Summary saved to: test_summary_${PYTORCH_VERSION}_${GFX_ARCH}.md"
echo ""
echo "To view summary: cat test_summary_${PYTORCH_VERSION}_${GFX_ARCH}.md"
