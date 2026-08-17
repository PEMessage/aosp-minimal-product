# BoardConfig.mk - minimum product (LineageOS 16.0 / Android 9)
# Minimal x86_64 board: no kernel, no bootloader, no images.
# Verified: lunch minimum-eng && m nothing build successfully.

TARGET_NO_BOOTLOADER := true
TARGET_NO_KERNEL := true

TARGET_ARCH := x86_64
TARGET_ARCH_VARIANT := x86_64
TARGET_CPU_ABI := x86_64

TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_USES_64_BIT_BINDER := true

# Skip bootanimation generation (no ImageMagick needed for a headless product).
TARGET_BOOTANIMATION := /dev/null

# Export kernel-related vars to soong: vendor/lineage's lineage_generator
# module (generated_kernel_includes) references $(KERNEL_MAKE_FLAGS) etc.
# Empty values are fine: the minimum product has no kernel.
SOONG_CONFIG_NAMESPACES += lineageVarsPlugin
SOONG_CONFIG_lineageVarsPlugin := KERNEL_ARCH KERNEL_CROSS_COMPILE KERNEL_MAKE_FLAGS TARGET_KERNEL_CONFIG TARGET_KERNEL_SOURCE
SOONG_CONFIG_lineageVarsPlugin_KERNEL_ARCH :=
SOONG_CONFIG_lineageVarsPlugin_KERNEL_CROSS_COMPILE :=
SOONG_CONFIG_lineageVarsPlugin_KERNEL_MAKE_FLAGS :=
SOONG_CONFIG_lineageVarsPlugin_TARGET_KERNEL_CONFIG :=
SOONG_CONFIG_lineageVarsPlugin_TARGET_KERNEL_SOURCE :=
