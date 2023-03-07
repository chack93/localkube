ARCH=$(arch)
if [ "${ARCH}" = "arm64" ]; then
  ARCH=aarch64
fi
if [ "${ARCH}" = "amd64" ]; then
  ARCH=x86_64
fi
echo ${ARCH}
