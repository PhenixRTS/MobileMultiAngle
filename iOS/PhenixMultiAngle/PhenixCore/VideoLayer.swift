//
//  Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
//

import AVFoundation

public class VideoLayer: AVSampleBufferDisplayLayer {
    public static let previewLayerName = "Video preview layer"
    private var observation: NSKeyValueObservation?

    override public init() {
        super.init()
        configure()
    }

    override public init(layer: Any) {
        super.init(layer: layer)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// Add primary preview layer to the provided layer as a sublayer
    ///
    /// Method automatically sets the destination size to the preview layer and creates a KVO observer for size changes.
    /// - Parameter layer: Destination layer provided by the app
    public func add(to layer: CALayer) {
        CATransaction.withoutAnimations {
            self.frame = layer.bounds
        }

        observation = layer.observe(\.bounds, options: [.new]) { [weak self] _, change in
            CATransaction.withoutAnimations {
                self?.frame = change.newValue ?? .zero
            }
        }
        layer.addSublayer(self)
    }
}

private extension VideoLayer {
    func configure() {
        name = Self.previewLayerName
        isOpaque = false
    }
}
