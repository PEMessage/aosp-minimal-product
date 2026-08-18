# Why the product is named `lineage_minimum` (not `minimum`)

When migrating this project from LineageOS 16.0 to 19.1, the product was
renamed from `minimum` to `lineage_minimum`. This is both deliberate (to
trigger the vendor hooks) and a hard requirement of the Android build system's
product mechanism.

## 1. The prefix triggers the vendor hooks

`build/envsetup.sh`'s `check_product` parses the product name and sets an
environment variable based on its prefix:

```sh
if (echo -n $1 | grep -q -e "^lineage_") ; then
    LINEAGE_BUILD=$(echo -n $1 | sed -e 's/^lineage_//g')
else
    LINEAGE_BUILD=
fi
```

And `build/make/core/config.mk` only loads the vendor/lineage config hooks when
`LINEAGE_BUILD` is non-empty:

```makefile
ifneq ($(LINEAGE_BUILD),)
include vendor/lineage/config/BoardConfigLineage.mk
endif
```

`BoardConfigLineage.mk` pulls in two key files:

- `config/BoardConfigKernel.mk` — kernel build variables (`KERNEL_ARCH`,
  `KERNEL_MAKE_FLAGS`, `KERNEL_MAKE_CMD`, ...).
- `config/BoardConfigSoong.mk` — exports those variables to soong's
  `lineageVarsPlugin` namespace (generating `SOONG_CONFIG_lineageVarsPlugin_*`
  automatically).

If the product were named `minimum`, `LINEAGE_BUILD` would be empty, the whole
vendor hook chain would be skipped, and `m nothing` would never exercise any of
the vendor-side logic — which contradicts this repo's goal of "exercising the
vendor hooks".

## 2. It also removes the hand-written SOONG config block

Back in 16.0, `BoardConfig.mk` had to manually declare a block like:

```makefile
SOONG_CONFIG_NAMESPACES += lineageVarsPlugin
SOONG_CONFIG_lineageVarsPlugin := KERNEL_ARCH KERNEL_CROSS_COMPILE ...
SOONG_CONFIG_lineageVarsPlugin_KERNEL_ARCH :=
...
```

In 19.1, as long as `LINEAGE_BUILD` is set, `BoardConfigSoong.mk` iterates over
`EXPORT_TO_SOONG` and generates these variables automatically, so `BoardConfig.mk`
no longer needs any `SOONG_CONFIG` block of its own.

## 3. The AndroidProducts mechanism requires a same-named file

`lunch lineage_minimum-eng` resolves the product name to a `<product>.mk` file
in the directories listed by `AndroidProducts.mk` (here `device/minimum/`):

```makefile
# device/minimum/AndroidProducts.mk
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/lineage_minimum.mk
```

So the product makefile must be renamed `minimum.mk` → `lineage_minimum.mk`,
and its `PRODUCT_NAME` must be `lineage_minimum`.

## Summary

| Item | 16.0 (old) | 19.1 (new) |
| --- | --- | --- |
| Product name | `minimum` | `lineage_minimum` |
| lunch | `lunch minimum-eng` | `lunch lineage_minimum-eng` |
| Makefile | `minimum.mk` | `lineage_minimum.mk` |
| `LINEAGE_BUILD` | empty (vendor hooks skipped) | `minimum` (hooks active) |
| SOONG config | hand-written `SOONG_CONFIG_lineageVarsPlugin_*` | auto-exported by `BoardConfigSoong.mk` |