# Test and release the iOS IPA

The workflow in `.github/workflows/build-ios-ipa.yml` tests the native iOS app
on an available iPhone simulator and creates an unsigned, device-targeted IPA
on a GitHub-hosted macOS runner. It does not need Apple Developer credentials
or repository secrets.

## Run it

1. Open the repository's **Actions** tab.
2. Select **Test and release iOS IPA**.
3. Choose **Run workflow**.
4. Download the `project-istiqamah-ios-sidestore` artifact when the package job passes.

Pull requests and pushes to `main` run the test suite. A manual run or a tag
whose name starts with `v` also builds the IPA. A version tag, such as `v1.0.1`,
creates or updates a GitHub Release and attaches the IPA to it.

## What the workflow does

The test job installs XcodeGen, generates the Xcode project from the checked-in
`project.json`, selects an installed iPhone simulator, and runs the unit and UI
test targets. Its `.xcresult` bundle is retained for 14 days, including when a
test fails.

For manual and version-tag runs, the package job builds the SwiftUI app and
ActivityKit widget extension for the physical-device SDK with code signing
disabled. It then places the app inside `Payload/`, creates
`ProjectIstiqamah-SideStore.ipa`, verifies the native Live Activity extension
is embedded, checks the archive, and uploads it for 14 days. A version-tag run
also attaches that IPA to the corresponding GitHub Release. Expo, React Native,
Node.js, and CocoaPods are not part of this build.

## Installing it

An unsigned IPA cannot be installed directly by tapping it. A sideloading tool
must sign it with an Apple ID or certificate before iOS will install it. The
workflow intentionally does not store or use signing credentials.

The app uses the bundle identifier `com.projectistiqamah.app`. If a signing tool
requires a different identifier, configure that in the signing tool or update
`PRODUCT_BUNDLE_IDENTIFIER` in `artifacts/project-istiqamah/project.json` before
building.
