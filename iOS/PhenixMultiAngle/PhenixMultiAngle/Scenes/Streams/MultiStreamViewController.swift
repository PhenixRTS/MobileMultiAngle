//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import os.log
import PhenixClosedCaptions
import PhenixCore
import UIKit

protocol ChannelProvider: AnyObject {
    var channels: [Channel] { get }
    var selectedChannel: Channel? { get }

    func replayStateDidChange(_ state: ChannelReplayController.State)
}

class MultiStreamViewController: UIViewController, Storyboarded, ChannelProvider {
    var phenixManager: PhenixChannelJoining!
    var channels: [Channel] = []
    var ccChannel: Channel?
    var device: UIDevice = .current

    private var replayController: MultiStreamReplayController!
    private var collectionViewManager: MultiStreamPreviewCollectionViewManager!
    private var selectedChannelIndexPath: IndexPath? {
        didSet {
            let indexPaths = [oldValue, selectedChannelIndexPath].compactMap { $0 }
            multiStreamView.reloadItems(at: indexPaths)
        }
    }

    internal private(set) var selectedChannel: Channel? {
        didSet {
            oldValue?.replay?.stopObservingPlaybackHead()

            guard let channel = selectedChannel else {
                return
            }

            updateReplayState()

            if channel.replay?.state == .playing {
                channel.replay?.startObservingPlaybackHead()
            }
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

        replayController = MultiStreamReplayController(channelProvider: self)
        replayController.configurePlayback(with: replayController.configuration)

        multiStreamView.delegate = self
        multiStreamView.configureUIElements()
        multiStreamView.setReplayConfigurationButtonTitle(replayController.configuration.title)
        multiStreamView.configurePreviewCollectionView(with: collectionViewManager)

        for channel in channels {
            join(channel)
        }
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

    func replayStateDidChange(_ state: ChannelReplayController.State) {
        updateReplayState()
    }
}

private extension MultiStreamViewController {
    func join(_ channel: Channel) {
        channel.addStreamObserver(self)
        channel.addTimeShiftObserver(self)
        channel.addTimeShiftObserver(replayController)
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
        guard collectionViewManager.channels.isEmpty == false else { return }
        let indexPath = selectedChannelIndexPath ?? IndexPath(item: 0, section: 0)
        self.select(channelAt: indexPath)
    }

    func showReplayConfiguration() {
        let ac = UIAlertController(title: "Select replay time", message: nil, preferredStyle: .actionSheet)
        for configuration in replayController.availableConfigurations {
            ac.addAction(UIAlertAction(title: configuration.title, style: .default) { [weak self] action in
                guard let self = self else { return }

                self.multiStreamView.setReplayConfigurationButtonTitle(configuration.title)
                self.replayController.configuration = configuration
            })
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }

    func updateReplayState() {
        guard let channel = selectedChannel else {
            multiStreamView.replay(state: .loading)
            return
        }

        guard channel.streamState == .playing else {
            // Need to wait for the channel stream to begin playing, before we can enable the replay mode.
            multiStreamView.replay(state: .loading)
            return
        }

        guard let state = channel.replay?.state else {
            // Replay controller does not exist and stream is already playing, so we can mark the replay state as a "failure".
            multiStreamView.replay(state: .failure)
            return
        }

        if replayController.inReplayMode == true && state == .readyToPlay {
            // Case, when it might be that we are waiting for all streams to become readyToPlay after seeking
            multiStreamView.replay(state: .seeking)
            return
        }

        multiStreamView.replay(state: state)
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

// MARK: - MultiStreamViewDelegate
extension MultiStreamViewController: MultiStreamViewDelegate {
    func replayModeDidChange(_ inReplayMode: Bool) {
        if inReplayMode {
            replayController.playStreamsIfPossible()
        } else {
            replayController.stopStreams()
        }
    }

    func replayConfigurationButtonTapped() {
        showReplayConfiguration()
    }

    func replayTimeSliderDidMove(_ time: TimeInterval) {
        replayController.movePlayback(by: time)
    }

    func restartReplayConfiguration() {
        replayController.configurePlayback(with: replayController.configuration)
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

            guard let channel = self.selectedChannel else { return }

            channel.media?.setAudio(enabled: true)
            self.updateReplayState()
        }
    }
}

// MARK: - ChannelTimeShiftObserver
extension MultiStreamViewController: ChannelTimeShiftObserver {
    func channel(_ channel: Channel, didChange state: ChannelReplayController.State) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard self.selectedChannel == channel else { return }

            self.updateReplayState()
        }
    }

    func channel(_ channel: Channel, didChangePlaybackHeadTo currentDate: Date, startDate: Date, endDate: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.multiStreamView.setReplayPlaybackHeadDate(startDate: startDate, currentDate: currentDate, endDate: endDate)
        }
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
