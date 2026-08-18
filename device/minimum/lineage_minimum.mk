# minimum.mk - minimal LineageOS product
# Inherits core_minimal (no apps, no framework build for `m nothing`).
# The "lineage_" prefix sets LINEAGE_BUILD so the build system pulls in
# vendor/lineage's BoardConfigKernel.mk / BoardConfigSoong.mk hooks.

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_minimal.mk)

PRODUCT_NAME := lineage_minimum
PRODUCT_DEVICE := minimum
PRODUCT_BRAND := minimum
PRODUCT_MODEL := Minimum
PRODUCT_MANUFACTURER := minimum
