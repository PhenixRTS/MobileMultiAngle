/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatActivity
import com.phenixrts.suite.phenixmultiangle.BuildConfig
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.cache.PreferenceProvider
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.ExpressError
import com.phenixrts.suite.phenixmultiangle.repository.ChannelExpressRepository
import kotlinx.android.synthetic.main.activity_splash.*
import timber.log.Timber
import javax.inject.Inject

private const val TIMEOUT_DELAY = 10000L

class SplashActivity : AppCompatActivity() {

    @Inject
    lateinit var channelExpressRepository: ChannelExpressRepository
    @Inject
    lateinit var preferenceProvider: PreferenceProvider

    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        launchMain {
            splash_root.showSnackBar(getString(R.string.err_network_problems))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MultiAngleApp.component.inject(this)
        setContentView(R.layout.activity_splash)
        channelExpressRepository.onChannelExpressError.observe(this, { error ->
            Timber.d("Room express failed")
            showErrorDialog(error)
        })
        checkDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        Timber.d("On new intent $intent")
        checkDeepLink(intent)
    }

    private fun checkDeepLink(intent: Intent?) {
        launchMain {
            Timber.d("Checking deep link: ${intent?.data}")
            var configuration: ChannelExpressConfiguration? = null
            if (intent?.data != null) {
                intent.data?.let { data ->
                    val channelAliases = (data.getQueryParameter(QUERY_CHANNEL_ALIASES) ?: BuildConfig.CHANNEL_ALIASES).split(",")
                    val mimeTypes = (data.getQueryParameter(QUERY_MIME_TYPES) ?: BuildConfig.MIME_TYPES).split(",")
                    val edgeAuth = data.getQueryParameter(QUERY_EDGE_AUTH)
                    val uri = data.getQueryParameter(QUERY_URI) ?: BuildConfig.PCAST_URL
                    val backend = data.getQueryParameter(QUERY_BACKEND) ?: BuildConfig.BACKEND_URL
                    ChannelExpressConfiguration(uri, backend, edgeAuth, channelAliases, mimeTypes).let { createdConfiguration ->
                        Timber.d("Checking deep link: $channelAliases $createdConfiguration")
                        configuration = createdConfiguration
                        if (channelExpressRepository.isRoomExpressInitialized()) {
                            Timber.d("New configuration detected")
                            preferenceProvider.saveConfiguration(createdConfiguration)
                            showErrorDialog(ExpressError.CONFIGURATION_CHANGED_ERROR)
                            return@launchMain
                        }
                        reloadConfiguration(createdConfiguration)
                    }
                }
            } else {
                preferenceProvider.getConfiguration()?.let { savedConfiguration ->
                    Timber.d("Loading saved configuration: $savedConfiguration")
                    configuration = savedConfiguration
                    reloadConfiguration(savedConfiguration)
                }
            }
            preferenceProvider.saveConfiguration(null)
            showLandingScreen(configuration)
        }
    }

    private suspend fun reloadConfiguration(configuration: ChannelExpressConfiguration) {
        timeoutHandler.postDelayed(timeoutRunnable, TIMEOUT_DELAY)
        channelExpressRepository.setupChannelExpress(configuration)
    }

    private fun showLandingScreen(configuration: ChannelExpressConfiguration?) = launchMain {
        if (configuration == null) {
            showErrorDialog(ExpressError.DEEP_LINK_ERROR)
            return@launchMain
        }
        Timber.d("Waiting for pCast")
        channelExpressRepository.waitForPCast()
        timeoutHandler.removeCallbacks(timeoutRunnable)
        Timber.d("Navigating to Landing Screen")
        startActivity(Intent(this@SplashActivity, MainActivity::class.java))
        finish()
    }
}
