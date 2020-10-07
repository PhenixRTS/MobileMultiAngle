/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.view.SurfaceView

private var isDrawingBitmap = false

fun Bitmap.scaleToSize(targetWidth: Int, targetHeight: Int): Bitmap {
    val ratioWidth = width.toFloat() / height.toFloat()
    val ratioHeight = height.toFloat() / width.toFloat()
    var finalWidth = targetWidth
    var finalHeight = targetHeight

    if (width < height) {
        finalHeight = if (height < targetHeight) (targetWidth.toFloat() * ratioHeight).toInt() else
            (targetWidth.toFloat() / ratioWidth).toInt()
    } else {
        finalWidth = if (width < targetWidth) (targetHeight.toFloat() * ratioWidth).toInt() else
            (targetHeight.toFloat() / ratioHeight).toInt()
    }
    return Bitmap.createScaledBitmap(this, finalWidth, finalHeight, true)
}

fun Canvas.drawScaledBitmap(bitmap: Bitmap, targetWidth: Int, targetHeight: Int) {
    val scaledBitmap = bitmap.scaleToSize(targetWidth, targetHeight)
    val offsetX = (targetWidth - scaledBitmap.width) * 0.5f
    val offsetY = (targetHeight - scaledBitmap.height) * 0.5f
    drawBitmap(scaledBitmap, offsetX, offsetY, Paint())
    scaledBitmap.recycle()
    bitmap.recycle()
}

fun SurfaceView.drawBitmap(bitmap: Bitmap) {
    if (!isDrawingBitmap) {
        isDrawingBitmap = true
        launchIO {
            holder?.let { holder ->
                holder.lockCanvas()?.let { canvas ->
                    canvas.drawScaledBitmap(bitmap, measuredWidth, measuredHeight)
                    holder.unlockCanvasAndPost(canvas)
                }
            }
            isDrawingBitmap = false
        }
    }
}
