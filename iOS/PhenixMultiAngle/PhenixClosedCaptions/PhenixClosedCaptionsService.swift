//
//  Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

public final class PhenixClosedCaptionsService {
    private weak var roomService: PhenixRoomService!
    private let chatService: PhenixRoomChatService
    private let decoder: JSONDecoder
    private let acceptableMimeTypes: [String] = ["text/subtitle"]
    private var disposables: [PhenixDisposable] = []

    public weak var delegate: PhenixClosedCaptionsServiceDelegate?

    /// A Boolean value indicating whether the Closed Captions service is enabled.
    ///
    /// If set to `true` then Closed Captions service will subscribe to receive the messages, or if set to `false` - unsubscribe from message retrieval.
    ///
    /// The default value of this property is true for a newly ClosedCaptions service.
    public var isClosedCaptionsEnabled: Bool {
        didSet {
            guard isClosedCaptionsEnabled != oldValue else {
                return
            }
            closedCaptionStateDidChange()
        }
    }

    public init(roomService: PhenixRoomService) {
        let batchSize: UInt = 0
        self.decoder = JSONDecoder()
        self.roomService = roomService
        self.chatService = PhenixRoomChatServiceFactory.createRoomChatService(roomService, batchSize, acceptableMimeTypes)
        self.isClosedCaptionsEnabled = true

        self.subscribeForLastChatMessage()
    }

    /// Clear saved reference objects, which may cause memory leaks if not released properly
    ///
    /// Always call this method before trying to destroy the Closed Caption service
    public func dispose() {
        disposables.removeAll()
    }
}

// MARK: - Private methods
private extension PhenixClosedCaptionsService {
    func subscribeForLastChatMessage() {
        os_log(.debug, log: .service, "Subscribe for closed caption messages")
        chatService.getObservableLastChatMessage()?.subscribe(lastChatMessageDidChange)?.append(to: &disposables)
    }

    func deliverClosedCaption(_ message: PhenixClosedCaptionMessage) {
        os_log(.debug, log: .service, "Deliver closed caption message to delegate")
        delegate?.closedCaptionsService(self, didReceive: message)
    }

    func closedCaptionStateDidChange() {
        if isClosedCaptionsEnabled {
            os_log(.debug, log: .service, "Enable closed captions")
            subscribeForLastChatMessage()
        } else {
            os_log(.debug, log: .service, "Disable closed captions")
            dispose()
        }
    }
}

// MARK: - Private observable callbacks
private extension PhenixClosedCaptionsService {
    func lastChatMessageDidChange(_ changes: PhenixObservableChange<PhenixChatMessage>?) {
        os_log(.debug, log: .service, "Did receive a message")
        guard let messageObject = changes?.value else {
            return
        }

        guard let message = messageObject.getObservableMessage()?.getValue() as String? else {
            os_log(.debug, log: .service, "Message is not a String object")
            return
        }

        guard let data = message.data(using: .utf8) else {
            os_log(.debug, log: .service, "Could not parse message into Data object using UTF8")
            return
        }

        do {
            let closedCaption = try decoder.decode(PhenixClosedCaptionMessage.self, from: data)
            deliverClosedCaption(closedCaption)
        } catch {
            os_log(.debug, log: .service, "Could not parse message into PhenixClosedCaptionMessage data model, error: %{PRIVATE}s", error.localizedDescription)
        }
    }
}
