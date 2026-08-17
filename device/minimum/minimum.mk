# minimum.mk - minimal LineageOS product
# Inherits core_minimal (no apps, no framework build for `m nothing`).

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_minimal.mk)

PRODUCT_NAME := minimum
PRODUCT_DEVICE := minimum
PRODUCT_BRAND := minimum
PRODUCT_MODEL := Minimum
PRODUCT_MANUFACTURER := minimum
