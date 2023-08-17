##### Interface Variables & Targets #####
BUILDROOT?=$(error "BUILDROOT has to be the path to the worker's build/ directory.")

# Renders one target per line in make order.  Each target will made with a
# build step with the 'get-steps' annotated builder (ve-linux.py).
get-steps:
	@echo "prepare"
	@echo "build-llvm"
	@echo "check-llvm"
	@echo "check-crt-ve"
# @echo "check-runtimes-ve"

##### Tools #####
CMAKE?=cmake
NINJA?=ninja
TOOL_CONFIG_CACHE?=${HOME}/tools-config.cmake

##### Derived Configuration #####

# Path
MONOREPO=${BUILDROOT}/../llvm-project

# Build foders
LLVM_BUILD=${BUILDROOT}/build_llvm

# 'Install' into the LLVM build tree.
LLVM_PREFIX=${BUILDROOT}/install

# Install prefix structure
X86_TARGET=x86_64-unknown-linux-gnu
VE_TARGET=ve-unknown-linux-gnu

### LLVM
LLVM_BUILD_TYPE=RelWithDebInfo
LLVM_OPTFLAGS=-O2
LLVM_TEST_OPTFLAGS=-O2

##### Build Steps #####

# Standalone build has been prohibited.  However, runtime build is not
# possible for VE because crt-ve is needed to be compiled by just compiled
# llvm.  Such bootstrap build CMakefile is not merged yet.  Check
# https://reviews.llvm.org/D89492 for details.
#
# As a result, we compile llvm for ve using following three steps.
#  1. Build llvm for X86 and VE with only X86 runtimes.
#  1.1 check-llvm
#  2. Build llvm for X86 and VE with x86 and VE compiler-rt runtimes.
#  2.1 check-compiler-rt for VE
#  3. Build x86 and VE all possible runtimes using 2.

### Vanilla LLVM stage ###
build-llvm:
	touch "${TOOL_CONFIG_CACHE}"
	mkdir -p "${LLVM_BUILD}"
	cd "${LLVM_BUILD}" && ${CMAKE} "${MONOREPO}/llvm" -G Ninja \
	      -C "${TOOL_CONFIG_CACHE}" \
	      -DCMAKE_BUILD_TYPE="${LLVM_BUILD_TYPE}" \
	      -DCMAKE_INSTALL_PREFIX="${LLVM_PREFIX}" \
	      -DCMAKE_CXX_FLAGS="${LLVM_OPTFLAGS}" \
	      -DCMAKE_C_FLAGS="${LLVM_OPTFLAGS}" \
	      -DCLANG_LINK_CLANG_DYLIB=Off \
	      -DLLVM_BUILD_LLVM_DYLIB=Off \
	      -DLLVM_LINK_LLVM_DYLIB=Off \
	      -DLLVM_ENABLE_TERMINFO=Off \
	      -DLLVM_ENABLE_ZLIB=Off \
	      -DLLVM_ENABLE_ZSTD=Off \
	      -DLLVM_TARGETS_TO_BUILD="X86;VE" \
	      -DLLVM_ENABLE_PROJECTS="clang" \
	      -DLLVM_ENABLE_RUNTIMES="compiler-rt;libunwind" \
	      -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=On \
	      -DLLVM_RUNTIME_TARGETS="${X86_TARGET};${VE_TARGET}" \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_BUILTINS=On \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_CRT=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_SANITIZERS=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_XRAY=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_LIBFUZZER=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_PROFILE=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_MEMPROF=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_ORC=Off \
	      -DRUNTIMES_${X86_TARGET}_COMPILER_RT_BUILD_GWP_ASAN=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_BUILTINS=On \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_CRT=On \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_SANITIZERS=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_XRAY=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_LIBFUZZER=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_PROFILE=On \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_MEMPROF=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_ORC=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_BUILD_GWP_ASAN=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_USE_BUILTINS_LIBRARY=On \
	      -DRUNTIMES_${VE_TARGET}_LIBCXXABI_USE_LLVM_UNWINDER=On \
	      -DRUNTIMES_${VE_TARGET}_LIBCXXABI_USE_COMPILER_RT=On \
	      -DRUNTIMES_${VE_TARGET}_LIBCXX_USE_COMPILER_RT=On \
	      -DRUNTIMES_${VE_TARGET}_LIBUNWIND_ENABLE_SHARED=Off \
	      -DRUNTIMES_${VE_TARGET}_COMPILER_RT_TEST_COMPILER_CFLAGS="-target ${VE_TARGET} ${LLVM_TEST_OPTFLAGS}" \
	      -DRUNTIMES_${VE_TARGET}_LIBCXXABI_TEST_COMPILER_CFLAGS="-target ${VE_TARGET} ${LLVM_TEST_OPTFLAGS}" \
	      -DRUNTIMES_${VE_TARGET}_LIBCXX_TEST_COMPILER_CFLAGS="-target ${VE_TARGET} ${LLVM_TEST_OPTFLAGS}" \
	      -DRUNTIMES_${VE_TARGET}_LIBUNWIND_TEST_COMPILER_CFLAGS="-target ${VE_TARGET} ${LLVM_TEST_OPTFLAGS}"
	cd "${LLVM_BUILD}" && ${NINJA}

check-llvm:
	# cd "${LLVM_BUILD}" && ${NINJA} check-all
	cd "${LLVM_BUILD}" && ${NINJA} check-clang
	cd "${LLVM_BUILD}" && ${NINJA} check-llvm
check-crt-ve:
	cd "${LLVM_BUILD}" && ${NINJA} check-compiler-rt-ve-unknown-linux-gnu
check-runtimes-ve:
	cd "${LLVM_BUILD}" && ${NINJA} check-runtimes-ve-unknown-linux-gnu

# Clearout the temporary install prefix.
prepare:
	# Build everything from scratch - TODO: incrementalize later.
	rm -rf "${LLVM_PREFIX}"
	rm -rf "${LLVM_BUILD}"
