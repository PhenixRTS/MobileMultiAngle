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

    private var timeShiftReplayConfigurations: [TimeShiftReplayConfiguration] = [.far, .near, .close]
    private var collectionViewManager: MultiStreamPreviewCollectionViewManager!
    private var selectedChannelIndexPath: IndexPath? {
        didSet {
            let indexPaths = [oldValue, selectedChannelIndexPath].compactMap { $0 }
            multiStreamView.reloadItems(at: indexPaths)
        }
    }
    private var selectedChannel: Channel? {
        didSet {
            oldValue?.stopObservingPlaybackHead()
            if replayState == .active {
                selectedChannel?.startObservingPlaybackHead()
            }
        }
    }
    private var alertController: UIAlertController?
    private var playbackHeadDidMove: Bool = false
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
        didSet {
            ccChannel?.isClosedCaptionsEnabled = isClosedCaptionsEnabled
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        multiStreamView.invalidateLayout()
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

        multiStreamView.delegate = self
        multiStreamView.configureUIElements()
        multiStreamView.setReplayConfigurationButtonTitle(TimeShiftReplayConfiguration.far.title)
        multiStreamView.configurePreviewCollectionView(with: collectionViewManager)

        for channel in channels {
            join(channel)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateChannelSelection()
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
    }

    /// Sets selected layer on the currently selected channel or the first channel in the channel list
    func updateChannelSelection() {
        if let indexPath = self.selectedChannelIndexPath {
            self.select(channelAt: indexPath)
        } else if collectionViewManager.channels.isEmpty == false {
            self.select(channelAt: IndexPath(item: 0, section: 0))
        }
    }

    func configurePlayback(with replayConfiguration: TimeShiftReplayConfiguration) {
        os_log(.debug, log: .ui, "Change replay configuration to %{PRIVATE}s", replayConfiguration.title)
        let initialDate = Date()
        for channel in channels {
            channel.startTimeShift(with: replayConfiguration, from: initialDate)
        }

        updateReplayState()
    }

    func replayStreams() {
        for channel in channels where channel.timeShiftState == .ready {
            channel.startReplay()
        }

        if let channel = selectedChannel {
            channel.startObservingPlaybackHead()
        }

        replayState = .active
    }

    func stopReplayingStreams() {
        for channel in channels where channel.timeShiftState == .ready {
            channel.stopReplay()
        }

        playbackHeadDidMove = false
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
                self.configurePlayback(with: configuration)
            })
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }

    func updateReplayState() {
        // Filter out channels, which are currently streaming
        let channels = self.channels.filter { $0.streamState == .playing }

        guard channels.isEmpty == false else {
            replayState = .notReady
            playbackHeadDidMove = false
            return
        }

        // Filter out failed channels, and check if all the rest of the channels are ready for replay
        let timeShiftChannels = channels.filter { $0.timeShiftState != .failure }

        guard timeShiftChannels.isEmpty == false else {
            replayState = .failure
            playbackHeadDidMove = false
            return
        }

        // Check if all available channel TimeShift is ready to replay
        let isTimeShiftReady = timeShiftChannels.allSatisfy { $0.timeShiftState == .ready }

        switch (isTimeShiftReady, playbackHeadDidMove) {
        case (true, true):
            replayState = .active
            playbackHeadDidMove = false
        case (true, false):
            replayState = .ready
        case (false, true):
            replayState = .waitingForPlayback
        case (false, false):
            replayState = .notReady
        }
    }

    func showAlert(withMessage message: String) {
        if let ac = self.alertController {
            ac.message = message
        } else {
            let ac = UIAlertController(title: "Channels failed to provide TimeShift", message: message, preferredStyle: .alert)
            alertController = ac
            ac.addAction(UIAlertAction(title: "OK", style: .cancel) { [weak self] _ in
                self?.alertController = nil
            })
            present(ac, animated: true)
        }
    }
}

extension MultiStreamViewController: ChannelStreamObserver {
    func channel(_ channel: Channel, didChange state: Channel.StreamState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.updateReplayState()

            // If channel state changed to playing, we need to limit its bandwidth if that isn't the Hero channel (selected channel)
            if state == .playing && channel != self.selectedChannel {
                channel.startBandwidthLimitation()
            }
        }
    }
}

extension MultiStreamViewController: ChannelTimeShiftObserver {
    func channel(_ channel: Channel, didChange state: ChannelTimeShiftWorker.TimeShiftAvailability) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            if state == .failure {
                // Collect all of the failed channel aliases
                let failedChannels = self.channels
                    .filter { $0.timeShiftState == .failure }
                    .map { $0.alias }
                    .joined(separator: ", ")

                self.showAlert(withMessage: failedChannels)

                if self.replayState == .active {
                    self.stopReplayingStreams()
                    return
                }
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
        playbackHeadDidMove = true
        for channel in channels where channel.timeShiftState == .ready {
            channel.movePlaybackHead(by: time)
        }
    }
}

extension MultiStreamViewController: PhenixClosedCaptionsServiceDelegate {
    public func closedCaptionsService(_ service: PhenixClosedCaptionsService, didReceive message: PhenixClosedCaptionsMessage) {
        DispatchQueue.main.async {
            os_log(.debug, log: .ui, "Did receive closed captions: %{PRIVATE}s", String(reflecting: message))
        }
    }
}
