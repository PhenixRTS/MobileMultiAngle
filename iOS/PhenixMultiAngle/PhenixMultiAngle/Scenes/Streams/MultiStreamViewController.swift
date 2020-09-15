//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixClosedCaptions
import PhenixCore
import UIKit

class MultiStreamViewController: UIViewController, Storyboarded {
    enum ReplayState: String {
        case notReady
        case ready
        case waitingForPlayback
        case active
    }

    var phenixManager: PhenixChannelJoining!
    var channels: [Channel] = []

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
        phenixManager.join(channel)
        channel.addTimeShiftObserver(self)
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
        let initialDate = Date()
        for channel in channels where channel.timeShiftState == .ready {
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
                guard configuration.title != self.multiStreamView.replayConfigurationTitle else {
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
        // Filter out failed channels, and check if all the rest of the channels are ready for replay
        let timeShiftChannels = channels.filter { $0.timeShiftState != .failure }
        let isTimeShiftReady = timeShiftChannels.allSatisfy { $0.timeShiftState == .ready }

        if timeShiftChannels.isEmpty {
            replayState = .notReady
        }

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

extension MultiStreamViewController: ChannelTimeShiftObserver {
    func channelTimeShiftStateDidChange(_ channel: Channel, state: ChannelTimeShiftWorker.TimeShiftAvailability) {
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

    func channelTimeShiftDidChangePlaybackHead(_ channel: Channel, startDate: Date, currentDate: Date, endDate: Date) {
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
    public func closedCaptionsService(_ service: PhenixClosedCaptionsService, didReceive message: PhenixClosedCaptionMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            os_log(.debug, log: .ui, "Did receive closed caption message: %{PRIVATE}s", message.debugDescription)

            self.multiStreamView.setCaption(message.textUpdates.first?.caption)
            self.multiStreamView.updateVisibilityForClosedCaptions(forReplay: self.replayState)
        }
    }
}
