//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixClosedCaptions
import PhenixSdk

internal protocol ChannelRepresentation: AnyObject {
    var alias: String { get }
}

public class Channel: ChannelRepresentation {
    private var replayOptions: ChannelReplayController.Options?

    internal var renderer: PhenixRenderer?
    internal var subscriber: PhenixExpressSubscriber?
    internal var roomService: PhenixRoomService?
    internal var joinObservations = [ObjectIdentifier: JoinObservation]()
    internal var streamObservations = [ObjectIdentifier: StreamObservation]()
    internal var timeShiftObservations = [ObjectIdentifier: TimeShiftObservation]()

    public let alias: String
    public private(set) var joinState: JoinState = .notJoined {
        didSet { channelJoinStateDidChange(state: joinState) }
    }
    public private(set) var streamState: StreamState = .noStreamPlaying {
        didSet { channelStreamStateDidChange(state: streamState) }
    }
    public private(set) var replay: ChannelReplayController?
    public private(set) var media: ChannelMediaController?

    // MARK: - Video preview layers

    /// Renders the main video on provided layer (hero view)
    public private(set) var primaryPreviewLayer: VideoLayer

    /// Renders the frame-ready output on provided layer (thumbnail view)
    public private(set) var secondaryPreviewLayer: VideoLayer

    // MARK: - ClosedCaptions section

    /// A Boolean value indicating whether the Closed Captions service should be initialized after a successful Channel joining.
    private var provideClosedCaptions: Bool
    private var closedCaptionsService: PhenixClosedCaptionsService?
    private weak var closedCaptionsView: PhenixClosedCaptionsView?
    public var isClosedCaptionsEnabled: Bool {
        get { closedCaptionsService?.isEnabled ?? false }
        set { closedCaptionsService?.isEnabled = newValue }
    }
    public weak var closedCaptionsServiceDelegate: PhenixClosedCaptionsServiceDelegate?

    // MARK: - Initialization

    public init(alias: String, closedCaptionsEnabled: Bool) {
        self.alias = alias
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
        media?.requestLastVideoFrame()
        secondaryPreviewLayer.add(to: layer)
    }

    public func setReplay(toStartAt date: Date, with configuration: ReplayConfiguration) {
        replayOptions = ChannelReplayController.Options(configuration: configuration, startDate: date)
        setupReplayController()
    }

    public func limitBandwidth(at bandwidth: PhenixBandwidthLimit) {
        os_log(.debug, log: .channel, "Start limiting bandwidth at %{PUBLIC}d, (%{PRIVATE}s)", bandwidth.rawValue, description)
        media?.limitBandwidth(at: bandwidth)
    }

    public func removeBandwidthLimitation() {
        os_log(.debug, log: .channel, "Remove bandwidth limitation, (%{PRIVATE}s)", description)
        media?.removeBandwidthLimitation()
    }

    public func setClosedCaptionsView(_ view: PhenixClosedCaptionsView) {
        closedCaptionsView = view
    }
}

public extension Channel {
    enum JoinState {
        case notJoined
        case pending
        case joined
        case failure
    }

    enum StreamState {
        case playing
        case noStreamPlaying
        case failure
    }
}

// MARK: - CustomStringConvertible
extension Channel: CustomStringConvertible {
    public var description: String {
        "Channel, alias: \(alias), join state: \(joinState), stream: \(streamState), media: \(media?.description ?? "-"),  replay: \(replay?.description ?? "-")"
    }
}

// MARK: - Private methods
private extension Channel {
    func setupMediaController() {
        guard let subscriber = subscriber else {
            return
        }

        guard let videoTrack = subscriber.getVideoTracks()?.first else {
            return
        }

        guard let renderer = renderer else {
            return
        }

        media = ChannelMediaController(subscriber: subscriber, renderer: renderer, secondaryPreviewLayer: secondaryPreviewLayer, channelRepresentation: self)
        media?.setAudio(enabled: false)
        media?.subscribe(videoTrack)
    }

    func setupReplayController() {
        guard let renderer = renderer else {
            return
        }

        guard let options = replayOptions else {
            assertionFailure("Options must be provided")
            return
        }

        replay = ChannelReplayController(renderer: renderer, options: options, channelRepresentation: self)
        replay?.delegate = self
        replay?.subscribe()
    }
}

// MARK: - Handler methods
internal extension Channel {
    func joinChannelHandler(status: PhenixRequestStatus, roomService: PhenixRoomService?) {
        os_log(.debug, log: .channel, "Connection state did change with state %{PUBLIC}d, (%{PRIVATE}s)", status.rawValue, description)
        self.roomService = roomService

        switch status {
        case .ok:
            joinState = .joined

            if provideClosedCaptions, let service = roomService {
                closedCaptionsService = makeClosedCationsService(with: service)
            }

        default:
            streamState = .noStreamPlaying
            joinState = .failure

            subscriber = nil
            renderer = nil
        }
    }

    func subscriberHandler(status: PhenixRequestStatus, subscriber: PhenixExpressSubscriber?, renderer: PhenixRenderer?) {
        os_log(.debug, log: .channel, "Stream state did change with state %{PUBLIC}d, (%{PRIVATE}s)", status.rawValue, description)
        self.renderer = renderer
        self.subscriber = subscriber

        switch status {
        case .ok:
            setupMediaController()
            setupReplayController()

            streamState = .playing

            os_log(.debug, log: .channel, "Channel set up finished, (%{PRIVATE}s)", description)

        case .noStreamPlaying:
            streamState = .noStreamPlaying

        default:
            streamState = .failure
        }
    }
}

// MARK: - ReplayDelegate
extension Channel: ReplayDelegate {
    func replayDidChangeState(_ state: ChannelReplayController.State) {
        channelTimeShiftStateDidChange(state: state)
    }

    func replayDidChangePlaybackHead(startDate: Date, currentDate: Date, endDate: Date) {
        channelTimeShiftPlaybackHeadDidChange(startDate: startDate, currentDate: currentDate, endDate: endDate)
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
