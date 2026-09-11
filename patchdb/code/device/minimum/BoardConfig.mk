# BoardConfig.mk - minimum product (LineageOS 19.1 / Android 12)
# Minimal x86_64 board: no kernel, no bootloader, no images.
# Verified: lunch lineage_minimum-eng && m nothing build successfully.
#
# Kernel-related SOONG config vars (SOONG_CONFIG_lineageVarsPlugin_*) are
# exported automatically by vendor/lineage/config/BoardConfigSoong.mk once
# LINEAGE_BUILD is set (product name starts with "lineage_"), so no manual
# SOONG_CONFIG block is needed here.

TARGET_NO_BOOTLOADER := true
TARGET_NO_KERNEL := true

TARGET_ARCH := x86_64
TARGET_ARCH_VARIANT := x86_64
TARGET_CPU_ABI := x86_64

TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_USES_64_BIT_BINDER := true
