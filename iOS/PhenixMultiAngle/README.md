# Phenix MultiAngle

## Build

*(Commands must be executed from the project's **root** directory)*

1. Install [Bundler](https://bundler.io) using Terminal:
```
gem install bundler
```

2. Install project environment dependencies listed in [Gemfile](Gemfile):
```
bundle install
```
This will install the [CocoaPods](https://cocoapods.org), which this project uses to link 3rd party frameworks.

3. Install project dependencies listed in [Podfile](Podfile):
```
bundle exec pod install
```

## Deep links

The application can only be opened using a deep link together with configuration parameters.
Without these parameters, application will automatically fail to open.

### Examples:

* `https://phenixrts.com/multiangle/?authToken=<authToken>&channelTokens=<streamToken>,<streamToken>,<streamToken>&channelAliases=<channelAlias>,<channelAlias>,<channelAlias>`

### Parameters

* `authToken` - Authentification token.
* `channelTokens` - Chanel stream tokens separated by `,` (comma).
* `channelAliases` - Chanel aliases separated by `,` (comma).

#### Notes

* The element count of `channelTokens` must match the element count of `channelAliases`, each `channelTokens` element index must match the appropriative `channelAliases` element index.

### Debugging

For easier deep link debugging, developer can use *Environment Variable* `PHENIX_DEEPLINK_URL` to inject a deep link on the application launch from Xcode.

Read more information about this in [PhenixDeeplink](../PhenixDeeplink/README.md).

## Debug menu

To open a debug menu, tap 5 times quickly anywhere in the application.
