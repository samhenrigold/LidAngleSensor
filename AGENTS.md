# LidAngleSensor Agent Guidelines

This is a macOS Objective-C application that interfaces with MacBook lid angle sensors.

## Build/Test Commands

Build Debug:
```bash
xcodebuild -project "LidAngleSensor.xcodeproj" -scheme "LidAngleSensor" -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" -arch arm64
```

Run App:
```bash
open build/Build/Products/Debug/LidAngleSensor.app
```

No formal tests exist. Testing requires running on Apple Silicon MacBook with lid sensor.

## Code Style

- **Language**: Objective-C with strict Apple conventions
- **Headers**: Include proper copyright headers with "Created by Sam on YYYY-MM-DD"
- **Imports**: Use `#import` not `#include`, system frameworks first, then local headers
- **Properties**: Use `@property` with explicit attributes: `(strong, nonatomic)`, `(assign, readonly)`
- **Memory**: Manual retain/release not needed (ARC enabled), use `CFRetain/CFRelease` for Core Foundation
- **Naming**: Camel case methods, descriptive names like `lidAngle`, `isAvailable`
- **Constants**: Use `NS_ENUM` for enumerations, static const for constants
- **Logging**: Use `NSLog(@"[ClassName] message")` format for debug output
- **Documentation**: Use `/**` comments for public methods with `@return` and `@param` tags