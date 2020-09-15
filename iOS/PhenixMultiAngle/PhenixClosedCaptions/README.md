# Phenix Closed Captions

Support library providing Closed Captions integration using PhenixSdk under-the-hood.

## Requirements
* iOS 12.0 or above

## Usage

1. Import `PhenixClosedCaptions` framework

```
import PhenixClosedCaptions
```

2. Confirm to the `PhenixClosedCaptionsServiceDelegate` protocol and implement required method:

```
extension ViewController: PhenixClosedCaptionsServiceDelegate {
    func closedCaptionsService(_ service: PhenixClosedCaptionsService, didReceive message: PhenixClosedCaptionMessage) {
        ...
    }
}
```

3. Create a `PhenixClosedCaptionsService` instance by providing to it `PhenixRoomService` instance and set the delegate. Keep a strong reference to the  `PhenixClosedCaptionsService` instance:

```
let roomService: PhenixRoomService = ...  // previously obtained
let closedCaptionsService = PhenixClosedCaptionsService(roomService: roomService)
closedCaptionsService.delegate = self
```

4. Create a `PhenixClosedCaptionView` instance and add it to the view hierarchy:

```
let closedCaptionView = PhenixClosedCaptionView()
view.addSubview(closedCaptionView)
```

5. When  `closedCaptionsService(_:didReceive:)` delegate method gets executed, update the `PhenixClosedCaptionView` instance to show the message:

```
func closedCaptionsService(_ service: PhenixClosedCaptionsService, didReceive message: PhenixClosedCaptionMessage) {
    DispatchQueue.main.async { [weak self] in
        self?.closedCaptionView.caption = message.textUpdates.first?.caption
    }
}
```
