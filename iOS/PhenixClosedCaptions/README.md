# Phenix Closed Captions

Support framework providing Closed Captions integration using `PhenixCore` under-the-hood.

## Requirements
* iOS 13.0+
* Xcode 12.5.1+
* Swift 5.4+
* PhenixCore framework

## Installation

### CocoaPods (using Development Pods)

[CocoaPods](https://cocoapods.org) is a dependency manager for Swift and Objective-C Cocoa projects.
For usage and installation instructions, visit their website.

To integrate `PhenixClosedCaptions` into your Xcode project using CocoaPods:

1. Move `PhenixClosedCaptions` directory inside your iOS project root directory.

2. Modify your `Podfile`:

```ruby
target 'your app name'
  use_frameworks!
  pod 'PhenixCore', :path => 'path/to/PhenixCore'
  pod 'PhenixClosedCaptions', :path => './PhenixClosedCaptions'
end
```

3. Install `Podfile` dependencies:

```shell
foo@bar Demo % pod install
```

## Usage

### Basic usage

1. Import `PhenixClosedCaptions` framework in the file in which you want to use it:

```swift
import PhenixClosedCaptions
```

2. Create a `PhenixClosedCaptionsController` instance by providing to it `PhenixCore` instance.

Remember to keep a strong reference of the `PhenixClosedCaptionsController` instance:

```swift
class ViewController: UIViewController {
    var core: PhenixCore! // previously obtained
    var closedCaptionsController: PhenixClosedCaptionsController!

    override func viewDidLoad() {
        // other code

        closedCaptionsController = PhenixClosedCaptionsController(core: core, queue: .main)
    }
}
```

3. Create a `PhenixClosedCaptionsView` instance. It will display all the received Closed Captions in it.

Add this view to the view hierarchy and pass it to the `PhenixClosedCaptionsController` instance:

```swift
class ViewController: UIViewController {
    var core: PhenixCore! // previously obtained
    var closedCaptionsController: PhenixClosedCaptionsController!

    override func viewDidLoad() {
        // other code

        let closedCaptionsView = PhenixClosedCaptionsView()
        view.addSubview(closedCaptionsView)

        // set “closedCaptionsView” size

        closedCaptionsController.setContainerView(closedCaptionsView)
    }
}
```

4. Subscribe for Closed Captions messages:

```swift
class ViewController: UIViewController {
    var core: PhenixCore! // previously obtained
    var closedCaptionsController: PhenixClosedCaptionsController!

    override func viewDidLoad() {
        // other code

        let alias: String = ... // previously obtained alias of the connected channel
        closedCaptionsController.subscribeForChannelMessages(alias: alias)
    }
}
```

### Advanced usage

If you want to provide a custom functionality for each received Closed Captions message,
you can conform to the `PhenixClosedCaptionsControllerDelegate` protocol.

1. Import `PhenixClosedCaptions` framework in the file in which you want to use it:

```swift
import PhenixClosedCaptions
```

2. Create a `PhenixClosedCaptionsController` instance by providing to it `PhenixCore` instance.

Remember to keep a strong reference of the `PhenixClosedCaptionsController` instance:

```swift
class ViewController: UIViewController {
    var core: PhenixCore! // previously obtained
    var label: UILabel!   // previously obtained, will hold closed captions messages
    var closedCaptionsController: PhenixClosedCaptionsController!

    override func viewDidLoad() {
        // other code

        closedCaptionsController = PhenixClosedCaptionsController(core: core, queue: .main)
    }
}
```

3. Adopt the `PhenixClosedCaptionsControllerDelegate` protocol:

```swift
extension ViewController: PhenixClosedCaptionsControllerDelegate {
    // ...
}
```

4. Implement required delegate methods and provide your own logic
for taking care of the Closed Captions messages:

```swift
extension ViewController: PhenixClosedCaptionsControllerDelegate {
    func closedCaptionsController(_ controller: PhenixClosedCaptionsController, didReceive message: PhenixClosedCaptionsMessage) {
        label.text = message.textUpdates.first?.caption
    }
}
```

5. Set the delegate for the `PhenixClosedCaptionsController` instance
to receive the `PhenixClosedCaptionsControllerDelegate` updates:

```swift
class ViewController {
    var core: PhenixCore! // previously obtained
    var label: UILabel!   // previously obtained, will hold closed captions messages
    var closedCaptionsController: PhenixClosedCaptionsController!

    override func viewDidLoad() {
        // other code

        closedCaptionsController.delegate = self
    }
}
```

### Tips

You can disable automatic user interface updates by setting the `PhenixClosedCaptionsService` instance container view to `nil`:

```swift
closedCaptionsController.setContainerView(nil)
```

Switch the Closed Captions service on/off by changing the `PhenixClosedCaptionsController.isEnabled` property:

```swift
closedCaptionsController.isEnabled = true
```

## Customization

It is possible to provide your own user interface property values
to customize the default look of the Closed Captions in multiple ways:

* Change the provided configuration property values on `PhenixClosedCaptionsView` instance:

```swift
closedCaptionsView.configuration.anchorPointOnTextWindow = CGPoint(x: 0.0, y: 0.0)
closedCaptionsView.configuration.positionOfTextWindow = CGPoint(x: 1.0, y: 1.0)
closedCaptionsView.configuration.widthInCharacters = 32
closedCaptionsView.configuration.heightInTextLines = 1
closedCaptionsView.configuration.textBackgroundColor = UIColor.black
...
```

* Provide your own customized property configuration
by creating a `PhenixClosedCaptionsConfiguration` instance and setting required property values.
Then provide this configuration to the `PhenixClosedCaptionsView` instance:

```swift
let customConfiguration = PhenixClosedCaptionsConfiguration(...)
closedCaptionsView.configuration = customConfiguration
```

* Modify few property values of the `PhenixClosedCaptionsConfiguration.default` configuration
and provide it to the `PhenixClosedCaptionsView` instance:

```swift
var modifiedConfiguration = PhenixClosedCaptionsConfiguration.default
modifiedConfiguration.textBackgroundAlpha = 0.5
closedCaptionsView.configuration = modifiedConfiguration
```
