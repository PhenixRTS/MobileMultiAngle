/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixcore.repositories.models.PhenixError
import com.phenixrts.suite.phenixcore.repositories.models.PhenixEvent
import com.phenixrts.suite.phenixcore.deeplink.DeepLinkActivity
import com.phenixrts.suite.phenixcore.deeplink.models.DeepLinkStatus
import com.phenixrts.suite.phenixcore.deeplink.models.PhenixDeepLinkConfiguration
import com.phenixrts.suite.phenixmultiangle.BuildConfig
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.ExpressError
import com.phenixrts.suite.phenixmultiangle.databinding.ActivitySplashBinding
import kotlinx.coroutines.flow.collect
import timber.log.Timber
import javax.inject.Inject

private const val TIMEOUT_DELAY = 10000L

@SuppressLint("CustomSplashScreen")
class SplashActivity : DeepLinkActivity() {

    @Inject lateinit var phenixCore: PhenixCore

    private lateinit var binding: ActivitySplashBinding
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        launchMain {
            binding.root.showSnackBar(getString(R.string.err_network_problems))
        }
    }

    override var defaultBackend = BuildConfig.BACKEND_URL

    override var defaultUri = BuildConfig.PCAST_URL

    override fun isAlreadyInitialized() = phenixCore.isInitialized

    override val additionalConfiguration: HashMap<String, String>
        get() = hashMapOf()

    override fun onCreate(savedInstanceState: Bundle?) {
        MultiAngleApp.component.inject(this)
        super.onCreate(savedInstanceState)
        binding = ActivitySplashBinding.inflate(layoutInflater)
        setContentView(binding.root)
        launchMain {
            phenixCore.onError.collect { error ->
                if (error == PhenixError.FAILED_TO_INITIALIZE) {
                    phenixCore.consumeLastError()
                    Timber.d("Splash: Failed to initialize Phenix Core: $error")
                    showErrorDialog(error.message)
                }
            }
        }
        launchMain {
            phenixCore.onEvent.collect { event ->
                Timber.d("Splash: Phenix core event: $event")
                if (event == PhenixEvent.PHENIX_CORE_INITIALIZED) {
                    phenixCore.consumeLastEvent()
                    showLandingScreen()
                }
            }
        }
    }

    override fun onDeepLinkQueried(
        status: DeepLinkStatus,
        configuration: PhenixDeepLinkConfiguration,
        rawConfiguration: Map<String, String>,
        deepLink: String
    ) {
        when (status) {
            DeepLinkStatus.RELOAD -> showErrorDialog(getErrorMessage(ExpressError.CONFIGURATION_CHANGED_ERROR))
            DeepLinkStatus.READY -> initializePhenixCore(configuration)
        }
    }

    private fun initializePhenixCore(configuration: PhenixDeepLinkConfiguration) {
        if (configuration.channels.isNullOrEmpty()) {
            showErrorDialog(getErrorMessage(ExpressError.DEEP_LINK_ERROR))
        } else {
            timeoutHandler.postDelayed(timeoutRunnable, TIMEOUT_DELAY)
            phenixCore.init(configuration)
        }
    }

    private fun showLandingScreen() {
        timeoutHandler.removeCallbacks(timeoutRunnable)
        Timber.d("Navigating to Landing Screen")
        startActivity(Intent(this@SplashActivity, MainActivity::class.java))
        finish()
    }
}
