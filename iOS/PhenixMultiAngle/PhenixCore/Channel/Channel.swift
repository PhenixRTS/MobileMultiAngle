//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

public class Channel {
    public enum JoinState {
        case notJoined
        case pending
        case joined
        case failure
    }

    public enum StreamState {
        case playing
        case noStreamPlaying
        case failure
    }

    enum AudioState {
        case none
        case mute
        case unmute
    }

    private var isSecondaryLayerFlushed = true

    public let alias: String
    public internal(set) var joinState: JoinState = .notJoined {
        didSet {
            channelJoinStateDidChange(state: joinState)
        }
    }
    public internal(set) var streamState: StreamState = .noStreamPlaying {
        didSet {
            channelStreamStateDidChange(state: streamState)
        }
    }

    internal var renderer: PhenixRenderer?
    internal var subscriber: PhenixExpressSubscriber?
    internal var roomService: PhenixRoomService?
    /// Helps to remember preferred audio state if it is provided before the renderer is created.
    internal var savedAudioState: AudioState = .none

    // MARK: - Observers

    internal var joinObservations = [ObjectIdentifier: JoinObservation]()
    internal var streamObservations = [ObjectIdentifier: StreamObservation]()

    // MARK: - Video preview layers

    /// Renders the main video on provided layer
    public private(set) var primaryPreviewLayer: VideoLayer
    /// Renders the frame-ready output on provided layer
    public private(set) var secondaryPreviewLayer: VideoLayer

    // MARK: - Initialization

    public init(alias: String) {
        self.alias = alias

        self.primaryPreviewLayer = VideoLayer()

        self.secondaryPreviewLayer = VideoLayer()
        self.secondaryPreviewLayer.videoGravity = .resizeAspectFill
    }

    /// Add primary preview layer to the provided layer as a sublayer
    ///
    /// Method automatically sets the destination size to the preview layer and creates a KVO observer for size changes.
    /// - Parameter layer: Destination layer provided by the app
    public func addPrimaryLayer(to layer: CALayer) {
        primaryPreviewLayer.add(to: layer)
    }

    /// Add primary preview layer to the provided layer as a sublayer
    ///
    /// Method automatically sets the destination size to the preview layer and creates a KVO observer for size changes.
    /// - Parameter layer: Destination layer provided by the app
    public func addSecondaryLayer(to layer: CALayer) {
        renderer?.requestLastVideoFrameRendered()
        secondaryPreviewLayer.add(to: layer)
    }

    /// Change channel audio state
    /// - Parameter enabled: True means that audio will be unmuted, false - muted
    public func setAudio(enabled: Bool) {
        guard let renderer = renderer else {
            os_log(.debug, log: .channel, "Cannot change audio, renderer is not available, (%{PRIVATE}s)", self.description)
            savedAudioState = enabled == true ? .unmute : .mute
            return
        }

        if enabled {
            os_log(.debug, log: .channel, "Unmute channel audio, (%{PRIVATE}s)", self.description)
            renderer.unmuteAudio()
        } else {
            os_log(.debug, log: .channel, "Mute channel audio, (%{PRIVATE}s)", self.description)
            renderer.muteAudio()
        }

        savedAudioState = .none
    }
}

// MARK: - Private methods
private extension Channel {
    /// Starts audio and video rendering
    ///
    /// Video rendering is started on primary preview layer and also on the second preview layer will be provided video if it will be added to the UI hierarchy.
    func startRendering() {
        guard let subscriber = subscriber else {
            return
        }

        guard let videoTrack = subscriber.getVideoTracks()?.first else {
            return
        }

        setAudio(enabled: savedAudioState == .unmute ? true : false)
        renderer?.setFrameReadyCallback(videoTrack, didReceiveVideoFrame)
        renderer?.setLastVideoFrameRenderedReceivedCallback(didReceiveLastVideoFrame)
    }
}

// MARK: - Observable callback methods
internal extension Channel {
    func didReceiveVideoFrame(_ frameNotification: PhenixFrameNotification?) {
        guard streamState == .playing else {
            return
        }

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
}

// MARK: - Handler methods
internal extension Channel {
    func joinChannelHandler(status: PhenixRequestStatus, roomService: PhenixRoomService?) {
        os_log(.debug, log: .channel, "Connection state did change with state %{PUBLIC}s, (%{PRIVATE}s)", String(describing: status), self.description)
        self.roomService = roomService

        switch status {
        case .ok:
            joinState = .joined
        default:
            streamState = .noStreamPlaying
            joinState = .failure
        }
    }

    func subscriberHandler(status: PhenixRequestStatus, subscriber: PhenixExpressSubscriber?, renderer: PhenixRenderer?) {
        os_log(.debug, log: .channel, "Stream state did change with state %{PUBLIC}s, (%{PRIVATE}s)", String(describing: status), self.description)
        self.renderer = renderer
        self.subscriber = subscriber

        switch status {
        case .ok:
            startRendering()
            streamState = .playing
        case .noStreamPlaying:
            streamState = .noStreamPlaying
        default:
            streamState = .failure
        }
    }
}

// MARK: - CustomStringConvertible
extension Channel: CustomStringConvertible {
    public var description: String {
        "Channel, alias: \(alias), join state: \(joinState), stream: \(streamState), audio muted: \(String(describing: renderer?.isAudioMuted))"
    }
}

// MARK: - Hashable
extension Channel: Hashable {
    public static func == (lhs: Channel, rhs: Channel) -> Bool {
        lhs.alias == rhs.alias
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(alias)
    }
}
