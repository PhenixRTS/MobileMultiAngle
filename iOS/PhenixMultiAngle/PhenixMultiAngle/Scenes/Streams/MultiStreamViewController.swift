//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixClosedCaptions
import PhenixCore
import UIKit

class MultiStreamViewController: UIViewController, Storyboarded {
    enum ReplayState: String {
        case notReady           // Time Shift is still loading or currently is not available.
        case failure            // Time Shift has failed to start.
        case ready              // Time Shift is ready to replay.
        case waitingForPlayback // Time Shift has moved its playback head and loading now.
        case active             // Time Shift is replaying right now.
    }

    var phenixManager: PhenixChannelJoining!
    var channels: [Channel] = []
    var ccChannel: Channel?
    var device: UIDevice = .current
    var replayConfiguration: ReplayConfiguration!

    private var timeShiftReplayConfigurations: [ReplayConfiguration] = [.far, .near, .close]
    private var collectionViewManager: MultiStreamPreviewCollectionViewManager!
    private var selectedChannelIndexPath: IndexPath? {
        didSet {
            let indexPaths = [oldValue, selectedChannelIndexPath].compactMap { $0 }
            multiStreamView.reloadItems(at: indexPaths)
        }
    }
    private var selectedChannel: Channel? {
        didSet {
            oldValue?.replay?.stopObservingPlaybackHead()

            updateReplayState()

            if replayState == .active {
                selectedChannel?.replay?.startObservingPlaybackHead()
            }
        }
    }
    private(set) var replayState: ReplayState = .notReady {
        didSet {
            os_log(.debug, log: .ui, "Change replay mode to: %{PRIVATE}s", replayState.rawValue)
            multiStreamView.replay(state: replayState)
        }
    }
    
    var multiStreamView: MultiStreamView {
        view as! MultiStreamView
    }

    var isClosedCaptionsEnabled: Bool = true {
        didSet { ccChannel?.isClosedCaptionsEnabled = isClosedCaptionsEnabled }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(phenixManager != nil, "Phenix Manager is required")

        collectionViewManager = MultiStreamPreviewCollectionViewManager()
        collectionViewManager.channels = channels
        collectionViewManager.isMemberIndexPathSelected = { [weak self] indexPath in
            self?.selectedChannelIndexPath == indexPath
        }
        collectionViewManager.itemSelectionHandler = { [weak self] selectedIndexPath in
            self?.select(channelAt: selectedIndexPath)
        }
        collectionViewManager.limitBandwidth = { [weak self] channel in
            self?.limitBandwidth(channel)
        }

        multiStreamView.delegate = self
        multiStreamView.configureUIElements()
        multiStreamView.setReplayConfigurationButtonTitle(ReplayConfiguration.far.title)
        multiStreamView.configurePreviewCollectionView(with: collectionViewManager)

        for channel in channels {
            join(channel)
        }

        configurePlayback(with: replayConfiguration)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateChannelSelection()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        multiStreamView.invalidateLayout()
        channels.forEach(limitBandwidth)
    }
}

private extension MultiStreamViewController {
    func join(_ channel: Channel) {
        channel.addStreamObserver(self)
        channel.addTimeShiftObserver(self)
        channel.setClosedCaptionsView(multiStreamView.closedCaptionsView)
        phenixManager.join(channel)
    }

    func select(channelAt indexPath: IndexPath) {
        guard indexPath != selectedChannelIndexPath else {
            return
        }

        let channel = collectionViewManager.channels[indexPath.item]
        os_log(.debug, log: .ui, "Select channel: %{PRIVATE}s", channel.description)

        selectedChannel = channel
        selectedChannelIndexPath = indexPath

        channel.addPrimaryLayer(to: multiStreamView.previewLayer)
        limitBandwidth(channel)
    }

    /// Sets selected layer on the currently selected channel or the first channel in the channel list
    func updateChannelSelection() {
        if let indexPath = self.selectedChannelIndexPath {
            self.select(channelAt: indexPath)
        } else if collectionViewManager.channels.isEmpty == false {
            self.select(channelAt: IndexPath(item: 0, section: 0))
        }
    }

    func configurePlayback(with replayConfiguration: ReplayConfiguration) {
        os_log(.debug, log: .ui, "Change replay configuration to %{PRIVATE}s", replayConfiguration.title)
        let date = Date()

        for channel in channels {
            channel.setReplay(toStartAt: date, with: replayConfiguration)
        }

        updateReplayState()
    }

    func replayStreams() {
        channels.forEachReplay(withState: .readyToPlay) { $0.startReplay() }

        selectedChannel?.replay?.startObservingPlaybackHead()
        replayState = .active
    }

    func stopReplayingStreams() {
        channels.forEachReplay(withState: .seeking) { $0.stopReplay() }
        channels.forEachReplay(withState: .playing) { $0.stopReplay() }

        updateReplayState()
    }

    func showReplayConfiguration() {
        let ac = UIAlertController(title: "Select replay time", message: nil, preferredStyle: .actionSheet)
        for configuration in timeShiftReplayConfigurations {
            ac.addAction(UIAlertAction(title: configuration.title, style: .default) { [weak self] action in
                guard let self = self else {
                    return
                }

                self.multiStreamView.setReplayConfigurationButtonTitle(configuration.title)
                self.replayConfiguration = configuration
                self.configurePlayback(with: configuration)
            })
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }

    func updateReplayState() {
        guard let channel = selectedChannel else {
            replayState = .notReady
            return
        }

        guard channel.streamState == .playing else {
            // Need to wait for the channel stream to begin playing, before we can enable the replay mode.
            replayState = .notReady
            return
        }

        guard let state = channel.replay?.state else {
            if channel.streamState == .playing {
                // Replay controller does not exist and stream is already playing, so we can mark the replay state as a "failure".
                replayState = .failure
            } else {
                // Stream is not playing so we still need to wait for the TimeShift.
                replayState = .notReady
            }
            return
        }

        switch state {
        case .loading,
             .ended:
            replayState = .notReady
        case .readyToPlay:
            replayState = .ready
        case .seeking:
            replayState = .waitingForPlayback
        case .playing:
            replayState = .active
        case .failure:
            replayState = .failure
        }
    }

    func limitBandwidth(_ channel: Channel) {
        if device.orientation.isLandscape {
            if channel == selectedChannel {
                channel.removeBandwidthLimitation()
            } else {
                channel.limitBandwidth(at: .offscreen)
            }
        } else {
            if channel == selectedChannel {
                channel.limitBandwidth(at: .hero)
            } else {
                channel.limitBandwidth(at: .thumbnail)
            }
        }
    }
}

// MARK: - ChannelStreamObserver
extension MultiStreamViewController: ChannelStreamObserver {
    func channel(_ channel: Channel, didChange state: Channel.StreamState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            // If channel state changed to playing we can start limiting the bandwidth
            if state == .playing {
                self.limitBandwidth(channel)
            }

            if channel == self.selectedChannel {
                channel.media?.setAudio(enabled: true)
                self.updateReplayState()
            }
        }
    }
}

// MARK: - ChannelTimeShiftObserver
extension MultiStreamViewController: ChannelTimeShiftObserver {
    func channel(_ channel: Channel, didChange state: ChannelReplayController.State) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            guard channel == self.selectedChannel else {
                return
            }

            self.updateReplayState()
        }
    }

    func channel(_ channel: Channel, didChangePlaybackHeadTo currentDate: Date, startDate: Date, endDate: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.multiStreamView.setReplayPlaybackHeadDate(startDate: startDate, currentDate: currentDate, endDate: endDate)
        }
    }
}

// MARK: - MultiStreamViewDelegate
extension MultiStreamViewController: MultiStreamViewDelegate {
    func replayModeDidChange(_ inReplayMode: Bool) {
        if inReplayMode {
            replayStreams()
        } else {
            stopReplayingStreams()
        }
    }

    func replayConfigurationButtonTapped() {
        showReplayConfiguration()
    }

    func replayTimeSliderDidMove(_ time: TimeInterval) {
        channels.forEachReplay(withState: .playing) { $0.movePlaybackHead(by: time) }
    }

    func restartReplayConfiguration() {
        configurePlayback(with: replayConfiguration)
    }
}

// MARK: - PhenixClosedCaptionsServiceDelegate
extension MultiStreamViewController: PhenixClosedCaptionsServiceDelegate {
    public func closedCaptionsService(_ service: PhenixClosedCaptionsService, didReceive message: PhenixClosedCaptionsMessage) {
        DispatchQueue.main.async {
            os_log(.debug, log: .ui, "Did receive closed captions: %{PRIVATE}s", String(reflecting: message))
        }
    }
}

// MARK: - Helpers
extension Sequence where Element == Channel {
    func forEachReplay(withState state: ChannelReplayController.State, do handle: (ChannelReplayController) -> Void) {
        let replays = compactMap { $0.replay }

        for replay in replays where replay.state == state {
            handle(replay)
        }
    }
}
