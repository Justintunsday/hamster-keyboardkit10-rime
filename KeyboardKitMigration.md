# KeyboardKit 10.9.4 migration

The keyboard extension now renders its key layout with the public
`KeyboardKit.KeyboardView` API from KeyboardKit 10.9.4. Hamster's Rime context
continues to own composition, candidate generation, candidate selection, and
commit insertion. `KeyboardKit10ActionHandler` routes character, space,
return, delete, and next-keyboard actions into that context.

KeyboardKit 10.9.4 is pinned by exact version and the verified revision
`e12297db0f4e5a032c44075b30af761ef09bdacf`. The package is a closed-source
binary SDK; this integration uses the Essentials APIs and does not add a Pro
license key or license file.

The KeyboardKit package product is attached to both the Hamster app and
The HamsterKeyboard extension because the extension owns the KeyboardKit 10
controller and view. Each target has its own PBXBuildFile record, so Xcode does
not reuse a framework phase entry across targets. All project targets are set to
iOS 16, which is the minimum supported deployment target of KeyboardKit 10.9.4.

Because this workspace is Windows based, Xcode cannot run here. On macOS,
open `Hamster.xcodeproj`, let Swift Package Manager resolve the pinned
KeyboardKit package, then build the `Hamster` scheme with the `HamsterKeyboard`
extension enabled. A device run still requires the normal Apple signing and
keyboard full-access setup.
