/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.widget.AdapterView
import android.widget.Spinner
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.snackbar.Snackbar
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.enums.ExpressError
import com.phenixrts.suite.phenixmultiangle.models.Channel
import java.text.SimpleDateFormat
import java.util.*
import kotlin.system.exitProcess

private fun AppCompatActivity.closeApp() {
    finishAffinity()
    finishAndRemoveTask()
    exitProcess(0)
}

private fun AppCompatActivity.getErrorMessage(error: ExpressError): String {
    return when (error) {
        ExpressError.DEEP_LINK_ERROR -> getString(R.string.err_invalid_deep_link)
        ExpressError.UNRECOVERABLE_ERROR -> getString(R.string.err_unrecoverable_error)
        ExpressError.CONFIGURATION_CHANGED_ERROR -> getString(R.string.err_configuration_changed)
    }
}

fun Channel.asString() = toString()

fun View.showSnackBar(message: String) = launchMain {
    Snackbar.make(this@showSnackBar, message, Snackbar.LENGTH_INDEFINITE).show()
}

fun AppCompatActivity.showErrorDialog(error: ExpressError) {
    AlertDialog.Builder(this, R.style.AlertDialogTheme)
        .setCancelable(false)
        .setMessage(getErrorMessage(error))
        .setPositiveButton(getString(R.string.popup_ok)) { dialog, _ ->
            dialog.dismiss()
            closeApp()
        }
        .create()
        .show()
}

fun View.setVisible(condition: Boolean) {
    val newVisibility = if (condition) View.VISIBLE else View.GONE
    if (visibility != newVisibility) {
        visibility = newVisibility
    }
}

fun Date.toDateString(): String = SimpleDateFormat("MM-dd-yyyy HH:mm:ss", Locale.getDefault()).format(this)

fun Spinner.onSelectionChanged(callback: (Int) -> Unit) {
    var lastSelectedPosition = 0
    onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
        override fun onNothingSelected(parent: AdapterView<*>?) {
            /* Ignored */
        }

        override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
            if (lastSelectedPosition != position) {
                lastSelectedPosition = position
                callback(position)
            }
        }
    }
}

fun SurfaceView.setCallback(onSurfaceAvailable: (Boolean) -> Unit): SurfaceHolder.Callback {
    val callback = object : SurfaceHolder.Callback {
        override fun surfaceCreated(p0: SurfaceHolder) {
            onSurfaceAvailable(true)
        }

        override fun surfaceChanged(p0: SurfaceHolder, p1: Int, p2: Int, p3: Int) {
            onSurfaceAvailable(true)
        }

        override fun surfaceDestroyed(p0: SurfaceHolder) {
            onSurfaceAvailable(false)
        }
    }
    holder.addCallback(callback)
    return callback
}
