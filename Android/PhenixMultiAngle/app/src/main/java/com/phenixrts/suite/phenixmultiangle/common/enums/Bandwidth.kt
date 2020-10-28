/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common.enums

enum class Bandwidth(val value: Long) {
    ULD(1000 * 80),
    VLD(1000 * 350),
    LD(1000 * 520),
    SD(1000 * 830),
    HD(1000 * 1600),
    FHD(1000 * 3000),
    XHD(1000 * 5500),
    UHD(1000 * 8500),
    UNLIMITED(0)
}
