//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixClosedCaptions
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

    private var bandwidthLimitationDisposables: [PhenixDisposable] = []

    internal var renderer: PhenixRenderer?
    internal var subscriber: PhenixExpressSubscriber?
    internal var roomService: PhenixRoomService?
    /// Helps to remember preferred audio state if it is provided before the renderer is created.
    internal var savedAudioState: AudioState = .none

    // MARK: - TimeShift

    internal var timeShiftWorker: ChannelTimeShiftWorker?
    public var timeShiftState: ChannelTimeShiftWorker.TimeShiftAvailability {
        timeShiftWorker?.state ?? .notReady
    }
    public var timeShiftStartTime: Date
    public var timeShiftReplayConfiguration: TimeShiftReplayConfiguration

    // MARK: - ClosedCaptions

    private var closedCaptionsService: PhenixClosedCaptionsService?
    /// A Boolean value indicating whether the Closed Captions service should be initialized after a successful Channel joining.
    private var provideClosedCaptions: Bool
    private weak var closedCaptionsView: PhenixClosedCaptionsView?
    public var isClosedCaptionsEnabled: Bool {
        get { closedCaptionsService?.isEnabled ?? false }
        set { closedCaptionsService?.isEnabled = newValue }
    }
    public weak var closedCaptionsServiceDelegate: PhenixClosedCaptionsServiceDelegate?

    // MARK: - Observers

    internal var joinObservations = [ObjectIdentifier: JoinObservation]()
    internal var streamObservations = [ObjectIdentifier: StreamObservation]()
    internal var timeShiftObservations = [ObjectIdentifier: TimeShiftObservation]()

    // MARK: - Video preview layers

    /// Renders the main video on provided layer
    public private(set) var primaryPreviewLayer: VideoLayer
    /// Renders the frame-ready output on provided layer
    public private(set) var secondaryPreviewLayer: VideoLayer

    // MARK: - Initialization

    public init(alias: String, timeShiftStartDateTime date: Date, replayConfiguration: TimeShiftReplayConfiguration, closedCaptionsEnabled: Bool) {
        self.alias = alias
        self.timeShiftStartTime = date
        self.timeShiftReplayConfiguration = replayConfiguration
        self.provideClosedCaptions = closedCaptionsEnabled

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

    public func startReplay() {
        timeShiftWorker?.startReplay()
    }

    public func stopReplay() {
        timeShiftWorker?.dispose()
        startTimeShift(with: timeShiftReplayConfiguration, from: timeShiftStartTime)
    }

    public func startObservingPlaybackHead() {
        timeShiftWorker?.subscribeForPlaybackHeadEvents()
    }

    public func stopObservingPlaybackHead() {
        timeShiftWorker?.unsubscribeForPlaybackHeadEvents()
    }

    public func startTimeShift(with replayConfiguration: TimeShiftReplayConfiguration, from startTime: Date) {
        createTimeShift(withInitialTime: startTime, replayConfiguration: replayConfiguration)
        timeShiftWorker?.subscribeForStatusEvents()
    }

    public func movePlaybackHead(by time: TimeInterval) {
        timeShiftWorker?.movePlaybackHead(by: time)
    }

    public func startBandwidthLimitation() {
        os_log(.debug, log: .channel, "Start limiting bandwidth, (%{PRIVATE}s)", self.description)

        guard let subscriber = subscriber else {
            os_log(.debug, log: .channel, "Subscriber is not available for bandwidth limitation, (%{PRIVATE}s)", self.description)
            return
        }

        subscriber.getVideoTracks()?.forEach { stream in
            stream.limitBandwidth(PhenixConfiguration.channelBandwidthLimitation).append(to: &bandwidthLimitationDisposables)
        }
        timeShiftWorker?.startBandwidthLimitation()
    }

    public func stopBandwidthLimitation() {
        os_log(.debug, log: .channel, "Stop limiting bandwidth, (%{PRIVATE}s)", self.description)
        bandwidthLimitationDisposables.removeAll()
        timeShiftWorker?.stopBandwidthLimitation()
    }

    public func setClosedCaptionsView(_ view: PhenixClosedCaptionsView) {
        closedCaptionsView = view
    }

    deinit {
        resetTimeShift()
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

    func createTimeShift(withInitialTime dateTime: Date, replayConfiguration: TimeShiftReplayConfiguration) {
        os_log(.debug, log: .channel, "Create new TimeShift instance with start date: %{PRIVATE}s, (%{PRIVATE}s)", dateTime.description, self.description)

        resetTimeShift()
        timeShiftStartTime = dateTime
        timeShiftReplayConfiguration = replayConfiguration
        timeShiftWorker = ChannelTimeShiftWorker(channel: self, initialDateTime: dateTime, configuration: replayConfiguration)
    }

    func resetTimeShift() {
        os_log(.debug, log: .channel, "Reset existing TimeShift, (%{PRIVATE}s)", self.description)
        timeShiftWorker?.dispose()
        timeShiftWorker = nil
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
}

// MARK: - Handler methods
internal extension Channel {
    func joinChannelHandler(status: PhenixRequestStatus, roomService: PhenixRoomService?) {
        os_log(.debug, log: .channel, "Connection state did change with state %{PUBLIC}d, (%{PRIVATE}s)", status.rawValue, description)
        self.roomService = roomService

        switch status {
        case .ok:
            if provideClosedCaptions, let service = roomService {
                closedCaptionsService = makeClosedCationsService(with: service)
            }

            joinState = .joined
        default:
            streamState = .noStreamPlaying
            joinState = .failure
        }
    }

    func subscriberHandler(status: PhenixRequestStatus, subscriber: PhenixExpressSubscriber?, renderer: PhenixRenderer?) {
        os_log(.debug, log: .channel, "Stream state did change with state %{PUBLIC}d, (%{PRIVATE}s)", status.rawValue, self.description)
        self.renderer = renderer
        self.subscriber = subscriber

        switch status {
        case .ok:
            startRendering()
            startTimeShift(with: timeShiftReplayConfiguration, from: timeShiftStartTime)

            streamState = .playing
        case .noStreamPlaying:
            streamState = .noStreamPlaying
        default:
            streamState = .failure
        }
    }
}

// MARK: - Closed Captions

private extension Channel {
    func makeClosedCationsService(with roomService: PhenixRoomService) -> PhenixClosedCaptionsService {
        let service = PhenixClosedCaptionsService(roomService: roomService)
        service.setContainerView(closedCaptionsView)
        service.delegate = closedCaptionsServiceDelegate
        return service
    }

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

// MARK: - CustomStringConvertible
extension Channel: CustomStringConvertible {
    public var description: String {
        """
        Channel, alias: \(alias),
                 join state: \(joinState),
                 stream: \(streamState),
                 audio muted: \(String(describing: renderer?.isAudioMuted)),
                 time shift state: \(String(describing: timeShiftWorker?.state))
        """
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
