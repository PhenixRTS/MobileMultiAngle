//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixSdk

public class ChannelMediaController {
    private weak var renderer: PhenixRenderer?
    private weak var subscriber: PhenixExpressSubscriber?
    private weak var secondaryPreviewLayer: VideoLayer!
    private var isSecondaryLayerFlushed = true
    private var bandwidthLimitationDisposables: [PhenixDisposable]

    internal weak var channelRepresentation: ChannelRepresentation?

    init(subscriber: PhenixExpressSubscriber, renderer: PhenixRenderer, secondaryPreviewLayer: VideoLayer, channelRepresentation: ChannelRepresentation? = nil) {
        self.subscriber = subscriber
        self.renderer = renderer
        self.bandwidthLimitationDisposables = []
        self.secondaryPreviewLayer = secondaryPreviewLayer
        self.channelRepresentation = channelRepresentation
    }

    /// Change channel audio state
    /// - Parameter enabled: True means that audio will be unmuted, false - muted
    public func setAudio(enabled: Bool) {
        if enabled {
            os_log(.debug, log: .mediaController, "Unmute audio, (%{PRIVATE}s)", channelDescription)
            renderer?.unmuteAudio()
        } else {
            os_log(.debug, log: .mediaController, "Mute audio, (%{PRIVATE}s)", channelDescription)
            renderer?.muteAudio()
        }
    }

    public func limitBandwidth(at bandwidth: PhenixBandwidthLimit) {
        os_log(.debug, log: .mediaController, "Limit bandwidth at %{PRIVATE}s, (%{PRIVATE}s)", bandwidth.description, channelDescription)

        bandwidthLimitationDisposables.removeAll()

        guard let subscriber = subscriber else {
            os_log(.debug, log: .mediaController, "Subscriber is not available, (%{PRIVATE}s)", channelDescription)
            return
        }
        subscriber.getVideoTracks()?.forEach { stream in
            stream.limitBandwidth(bandwidth.rawValue).append(to: &bandwidthLimitationDisposables)
        }
    }

    public func removeBandwidthLimitation() {
        os_log(.debug, log: .mediaController, "Remove bandwidth limitation, (%{PRIVATE}s)", channelDescription)
        bandwidthLimitationDisposables.removeAll()
    }
}

// MARK: - Internal methods
internal extension ChannelMediaController {
    func subscribe(_ videoTrack: PhenixMediaStreamTrack) {
        os_log(.debug, log: .mediaController, "Subscribe to video, (%{PRIVATE}s)", channelDescription)
        renderer?.setFrameReadyCallback(videoTrack, didReceiveVideoFrame)
        renderer?.setLastVideoFrameRenderedReceivedCallback(didReceiveLastVideoFrame)
        renderer?.setVideoDisplayDimensionsChangedCallback(didReceiveVideoDisplayDimensionsChange)
    }

    func requestLastVideoFrame() {
        renderer?.requestLastVideoFrameRendered()
    }
}

// MARK: - Private methods
private extension ChannelMediaController {
    var channelDescription: String { channelRepresentation?.alias ?? "-" }

    func modify(_ sampleBuffer: CMSampleBuffer) {
        if let attachmentArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
            let count = CFArrayGetCount(attachmentArray)
            for index in 0..<count {
                if let unsafeRawPointer = CFArrayGetValueAtIndex(attachmentArray, index) {
                    let attachments = unsafeBitCast(unsafeRawPointer, to: CFMutableDictionary.self)
                    // Need to set the sample buffer to display frame immediately and ignore whatever timestamps are included.
                    // Without this, iOS 14 will not render the frames.
                    CFDictionarySetValue(attachments,
                                         unsafeBitCast(kCMSampleAttachmentKey_DisplayImmediately, to: UnsafeRawPointer.self),
                                         unsafeBitCast(kCFBooleanTrue, to: UnsafeRawPointer.self))
                }
            }
        }
    }
}

// MARK: - Observable callbacks
private extension ChannelMediaController {
    func didReceiveVideoFrame(_ frameNotification: PhenixFrameNotification?) {
        // If layer is not added to the view hierarchy, there is no need to render the media on it.
        guard secondaryPreviewLayer.superlayer != nil else {
            if isSecondaryLayerFlushed == false {
                secondaryPreviewLayer.flushAndRemoveImage()
                isSecondaryLayerFlushed = true
            }
            return
        }

        isSecondaryLayerFlushed = false

        frameNotification?.read { [weak self] sampleBuffer in
            guard let self = self else {
                return
            }

            guard let sampleBuffer = sampleBuffer else {
                return
            }

            self.modify(sampleBuffer)

            if self.secondaryPreviewLayer.isReadyForMoreMediaData {
                self.secondaryPreviewLayer.enqueue(sampleBuffer)
            }
        }
    }

    func didReceiveLastVideoFrame(_ renderer: PhenixRenderer?, _ nativeVideoFrame: CVPixelBuffer?) {
        guard let nativeVideoFrame = nativeVideoFrame else {
            return
        }

        if secondaryPreviewLayer.isReadyForMoreMediaData {
            if let frame = nativeVideoFrame.createSampleBufferFrame() {
                secondaryPreviewLayer.enqueue(frame)
            }
        }
    }

    func didReceiveVideoDisplayDimensionsChange(_ renderer: PhenixRenderer?, _ dimensions: UnsafePointer<PhenixDimensions>?) {
        guard let dimensions = dimensions?.pointee else {
            return
        }

        os_log(.debug, log: .mediaController, "Frame dimensions changed - width: %{PRIVATE}d,\theight: %{PRIVATE}d, (%{PRIVATE}s)", dimensions.width, dimensions.height, channelDescription)
    }
}
