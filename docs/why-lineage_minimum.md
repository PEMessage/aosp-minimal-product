# Why the product is named `lineage_minimum` (not `minimum`)

The product is deliberately named `lineage_minimum`: the `lineage_` prefix is
what makes the build system pull in the vendor hooks, so `m nothing` exercises
the vendor-side logic instead of skipping it.

## 1. The prefix triggers the vendor hooks

`build/envsetup.sh`'s `check_product` sets `LINEAGE_BUILD` from the prefix:

```sh
if (echo -n $1 | grep -q -e "^lineage_") ; then
    LINEAGE_BUILD=$(echo -n $1 | sed -e 's/^lineage_//g')
else
    LINEAGE_BUILD=
fi
```

`build/make/core/config.mk` only loads the vendor config when it is non-empty:

```makefile
ifneq ($(LINEAGE_BUILD),)
include vendor/lineage/config/BoardConfigLineage.mk
endif
```

`BoardConfigLineage.mk` then pulls in `config/BoardConfigKernel.mk` (kernel
build variables: `KERNEL_ARCH`, `KERNEL_MAKE_FLAGS`, ...) and
`config/BoardConfigSoong.mk`, which exports those variables to soong's
`lineageVarsPlugin` namespace (`SOONG_CONFIG_lineageVarsPlugin_*`).

Named `minimum`, `LINEAGE_BUILD` would be empty, the whole vendor hook chain
would be skipped, and `m nothing` would never exercise any vendor-side logic —
contradicting this repo's goal of exercising the vendor hooks.

## 2. The AndroidProducts mechanism requires a same-named file

`lunch lineage_minimum-eng` resolves the product name to a `<product>.mk` file
in the directories listed by `AndroidProducts.mk` (here the in-tree
`code/device/minimum/`, a patchman copy entry):

```makefile
# code/device/minimum/AndroidProducts.mk
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/lineage_minimum.mk
```

So the product makefile must be `lineage_minimum.mk` and its `PRODUCT_NAME`
must be `lineage_minimum`.

## Summary

| Item | Value |
| --- | --- |
| Product name | `lineage_minimum` |
| lunch | `lunch lineage_minimum-eng` |
| Makefile | `lineage_minimum.mk` |
| `LINEAGE_BUILD` | `minimum` (vendor hooks active) |
| SOONG config | auto-exported by `BoardConfigSoong.mk`, no hand-written block |
