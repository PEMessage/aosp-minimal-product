#!/usr/bin/env bash

source build/envsetup.sh
lunch lineage_minimum-eng
export ALLOW_MISSING_DEPENDENCIES=true
# export CKATI_WAIT_USR2=1
m nothing
