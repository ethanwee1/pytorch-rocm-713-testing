#!/bin/bash
# Trigger Docker builds for PyTorch 2.9, 2.10, 2.11 with ROCm 7.13 and Python 3.10

set -e

REPO="ROCm/pytorch"
WORKFLOW="build_portable_linux_pytorch_dockers.yml"
PYTHON_VERSION="3.10"
INDEX_URL="https://rocm.prereleases.amd.com/"
# Available in prereleases: 7.9.0rc1, 7.10.0rc0-2, 7.11.0rc0-2, 7.12.0rc1
# Set to specific version or leave empty to auto-discover from latest wheel
ROCM_VERSION="7.12.0rc1"  # Update to 7.13 when available in prereleases

# Array of PyTorch versions to build
PYTORCH_VERSIONS=("2.9" "2.10" "2.11")

# Array of GFX architectures
GFX_ARCHS=("gfx950-dcgpu" "gfx94X-dcgpu" "gfx90X-dcgpu")

echo "=========================================="
echo "Triggering Docker Builds"
echo "=========================================="
echo "Python: ${PYTHON_VERSION}"
echo "ROCm Index: ${INDEX_URL}"
echo "PyTorch Versions: ${PYTORCH_VERSIONS[@]}"
echo "GFX Architectures: ${GFX_ARCHS[@]}"
echo "=========================================="
echo ""

# Function to trigger a workflow
trigger_build() {
    local pytorch_version=$1
    local gfx_arch=$2

    echo "Triggering build for PyTorch ${pytorch_version} on ${gfx_arch}..."

    gh workflow run "${WORKFLOW}" \
        --repo "${REPO}" \
        --ref develop \
        -f pytorch_repo="ROCm/pytorch" \
        -f pytorch_branch="release/${pytorch_version}" \
        -f python_version="${PYTHON_VERSION}" \
        -f amdgpu_family="${gfx_arch}" \
        -f rocm_version="${ROCM_VERSION}" \
        -f index_url="${INDEX_URL}"

    if [ $? -eq 0 ]; then
        echo "✓ Triggered PyTorch ${pytorch_version} ${gfx_arch}"
    else
        echo "✗ Failed to trigger PyTorch ${pytorch_version} ${gfx_arch}"
    fi

    # Small delay between triggers
    sleep 2
}

# Trigger builds for each combination
for pytorch_version in "${PYTORCH_VERSIONS[@]}"; do
    for gfx_arch in "${GFX_ARCHS[@]}"; do
        trigger_build "${pytorch_version}" "${gfx_arch}"
    done
    echo ""
done

echo ""
echo "=========================================="
echo "All builds triggered!"
echo "=========================================="
echo ""
echo "To monitor the workflow runs:"
echo "  gh run list --repo ${REPO} --workflow ${WORKFLOW} --limit 20"
echo ""
echo "To watch a specific run:"
echo "  gh run watch <run-id> --repo ${REPO}"
echo ""
echo "Once builds complete, use pull_and_test_dockers.sh to pull images and run tests"
