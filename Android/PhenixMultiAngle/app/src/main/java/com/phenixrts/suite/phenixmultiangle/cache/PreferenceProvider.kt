/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.cache

import android.content.Context
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.common.ChannelExpressConfiguration
import com.phenixrts.suite.phenixmultiangle.common.fromJson
import com.phenixrts.suite.phenixmultiangle.common.toJson

private const val APP_PREFERENCES = "group_preferences"
private const val CONFIGURATION = "configuration"

class PreferenceProvider(private val context: MultiAngleApp) {

    fun saveConfiguration(configuration: ChannelExpressConfiguration?) {
        context.getSharedPreferences(APP_PREFERENCES, Context.MODE_PRIVATE).edit()
            .putString(CONFIGURATION, configuration?.toJson())
            .apply()
    }

    fun getConfiguration(): ChannelExpressConfiguration? {
        var configuration: ChannelExpressConfiguration? = null
        context.getSharedPreferences(APP_PREFERENCES, Context.MODE_PRIVATE).getString(CONFIGURATION, null)?.let { cache ->
            configuration = cache.fromJson()
        }
        return configuration
    }
}
