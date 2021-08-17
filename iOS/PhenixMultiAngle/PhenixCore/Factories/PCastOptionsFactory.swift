//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import Foundation
import os.log
import PhenixSdk

enum PCastOptionsFactory {
    typealias UnrecoverableErrorHandler = (_ description: String?) -> Void

    static func makePCastExpressOptions(
        configuration: PhenixConfiguration,
        unrecoverableErrorCallback: @escaping UnrecoverableErrorHandler
    ) -> PhenixPCastExpressOptions {
        let pcastExpressOptionsBuilder: PhenixPCastExpressOptionsBuilder = PhenixPCastExpressFactory
            .createPCastExpressOptionsBuilder()
            .withMinimumConsoleLogLevel(configuration.logLevel.rawValue)
            .withUnrecoverableErrorCallback { _, description in
                os_log(
                    .error,
                    log: .phenixManager,
                    "Unrecoverable Error: %{private}s",
                    String(describing: description)
                )
                unrecoverableErrorCallback(description)
            }

        if let authToken = configuration.edgeToken {
            pcastExpressOptionsBuilder.withAuthenticationToken(authToken)
        } else if let backend = configuration.backend {
            pcastExpressOptionsBuilder.withBackendUri(backend.absoluteString)
        }

        if let pcast = configuration.pcast {
            pcastExpressOptionsBuilder.withPCastUri(pcast.absoluteString)
        }

        return pcastExpressOptionsBuilder.buildPCastExpressOptions()
    }
}
