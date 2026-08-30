# investlink-webrtc

Prebuilt WebRTC artifacts for the InvestLink mobile app, carrying
`ExternalAudioSource` so screen-share audio is published as **its own track**
rather than mixed into the microphone.

**This repo holds binaries only.** The source delta, the build scripts and the
verifier live in the mobile repo under `native/webrtc-external-audio/` — start
with its `BUILD-RUNBOOK.md`.

## Why it exists

The stock `io.github.webrtc-sdk` binary cannot publish a second local audio
source: `libjingle_peerconnection_so.so` exports only JNI stubs and no C++
symbols, and `LocalAudioSource::AddSink` is an empty no-op, so every local audio
track is fed by the one audio device module. Our delta fills that hole. The
runbook has the full evidence.

## Contents

```
maven/          static maven repo — the Android AAR, consumed over plain HTTPS
ios/            the XCFramework zip + its podspec, consumed over plain HTTPS
checksums.sh    regenerate .sha1/.md5 sidecars after changing any maven artifact
```

## Consuming it

### Android

```gradle
repositories {
    maven { url 'https://raw.githubusercontent.com/ImperatorJake/investlink-webrtc/main/maven' }
}

dependencies {
    api 'com.investlink:webrtc-android:144.7559.05-il1'
}
```

replacing `api 'io.github.webrtc-sdk:android:144.7559.05'` in
`@livekit/react-native-webrtc`'s `android/build.gradle`. Do that swap through
`scripts/patch-webrtc-native.js` in the mobile repo, not by hand — it survives
`yarn install` and fails loudly if upstream moves the line.

### iOS

Two halves, and BOTH are required — see `plugins/withInvestLinkWebRTC.js` and
patch 11 of `scripts/patch-webrtc-native.js` in the mobile repo:

1. The Podfile declares the pod with an explicit `:podspec` URL. CocoaPods
   resolves dependencies only from Podfile-declared sources, and this pod is not
   in the trunk spec repo, so without this a dependency on it fails with
   `Unable to find a specification for InvestLinkWebRTC` — which reads like a
   typo rather than a missing source.

   ```ruby
   pod 'InvestLinkWebRTC', :podspec =>
     'https://raw.githubusercontent.com/ImperatorJake/investlink-webrtc/main/ios/InvestLinkWebRTC.podspec'
   ```

2. `livekit-react-native-webrtc.podspec`'s `s.dependency 'WebRTC-SDK', '=144.7559.10'`
   is swapped for `'InvestLinkWebRTC', '=144.7559.10-il2'`.

   Both this and the Android coordinate above are generated from
   `scripts/webrtc-version.js` in the mobile repo — that file is the single
   source of truth for both, so bump it there rather than editing either
   consumer by hand.

The gradle side needs only the equivalent of (2) because its `maven { url }`
block does (1)'s job inline.

## 🔴 Do not enable Git LFS on this repo

Both artifacts are fetched through `raw.githubusercontent.com`. If either is
stored in LFS, that URL returns the **pointer text file**, not the binary — and
the failure surfaces as a confusing "not a valid zip" or checksum error that
mentions nothing about LFS. Both must be plain git blobs.

That is the price of serving binaries over unauthenticated HTTPS, which is what
EAS CI needs, and it is why the repo tolerates binaries in its history at all.

## Versioning

`<upstream-version>-il<n>` — e.g. `144.7559.05-il1`.

- Change the version part only when the **upstream commit** changes.
- Bump `il<n>` for a rebuild of the same upstream commit (a fix in our delta).

## 🔴 The platforms build from DIFFERENT upstream commits, on purpose

Android `144.7559.05` (`6c1aa903`), iOS `144.7559.10` (`f47af7bc`).

This looks like drift and is not. `@livekit/react-native-webrtc` pins
`io.github.webrtc-sdk:android:144.7559.05` in gradle and `WebRTC-SDK
=144.7559.10` in its podspec because **its iOS code calls ObjC APIs that only
exist from `.10`** — `WebRTCModule+RTCAudioDeviceModule.m` uses
`setPlatformVoiceProcessingAllowed:`, `platformAudioProcessingState` and
`isVoiceProcessingEnabledRequested`, none of which are in `.05`'s
`RTCAudioDeviceModule.h`. Build iOS at `.05` and the POD fails to compile:

```
no visible @interface for 'RTCAudioDeviceModule' declares the selector
'setPlatformVoiceProcessingAllowed:'
```

An earlier version of this file claimed the opposite — that `.10` was purely
additive and unused, so both platforms could share `.05`. That was based on
grepping for a handful of expected symbol names rather than deriving them from
the header diff, and it was wrong. iOS was built at `.05`, published, and only
failed at the first real `xcodebuild`. **Do not "fix" this disagreement.** If
you upgrade, take each platform to the version ITS side of the package requires
and let a compile prove it, because nothing earlier in the chain will.

## Adding an Android artifact

1. Build and verify it (`verify-artifact.sh` in the mobile repo — a green build
   proves nothing about an artifact's contents).
2. Drop the AAR into `maven/com/investlink/webrtc-android/<version>/` as
   `webrtc-android-<version>.aar`, with a matching `.pom`.
3. Update `maven-metadata.xml`.
4. Run `./checksums.sh`.
5. Record upstream commit, harness tag, delta commit SHA and checksums in
   `PROVENANCE.md`. Without it the next upgrade is archaeology.

## Adding an iOS artifact

The XCFramework has to be built on a Mac. Start from
`native/webrtc-external-audio/BUILD-RUNBOOK.md` and
`notes/ios-screen-audio-handoff.md` in the mobile repo; this section is only
about publishing what comes out.

**It is committed, exactly like the AAR.** An earlier draft sent it to a GitHub
Release asset on the grounds that an XCFramework is ~300MB — but that assumed
the stock pod's eleven slices (macOS, Mac Catalyst, tvOS, visionOS). An
iOS-only build is 17MB, smaller than the AAR already in this repo, so the
objection did not survive contact with a real artifact and both platforms now
use one hosting mechanism. If you ever DO publish all eleven slices, revisit
this — at that size a Release asset is the right call again.

1. Build it, then verify — the iOS half of the verifier checks that the header
   is exported from the framework and that each slice's binary really contains
   the class, which are different failures:

   ```bash
   ./native/webrtc-external-audio/verify-artifact.sh ios <path-to-xcframework-or-zip>
   ```

2. Zip it as `WebRTC.xcframework.zip`.
3. Commit it to a **version-scoped** path: `ios/<version>/WebRTC.xcframework.zip`.
   The version lives in the PATH, which is what lets the podspec point at `main`
   without a rebuild ever changing what an existing `s.version` resolves to —
   the same property the maven layout relies on. Never overwrite a published
   directory; publish a new one and bump `-il<n>`.
4. In `ios/InvestLinkWebRTC.podspec`, set `s.version` and update `:sha256` to
   the new zip's. Check the deployment targets still match the stock
   `WebRTC-SDK` pod — raising them silently raises the whole app's floor, and
   declaring a platform you have no slice for fails at LINK time, not at
   `pod install`.
5. Add an iOS section to `PROVENANCE.md`: upstream commit, harness tag, delta
   commit SHA, Xcode version, and the zip's SHA-256.
6. Sanity-check the published URL actually serves the binary before wiring the
   pod up:

   ```bash
   curl -sSIL <raw-githubusercontent-url> | grep -iE "^(HTTP|content-length|content-type)"
   ```

   That is the same check that proved the Android path — fetching the exact URL
   the build tool will use, rather than trusting that it works. A few hundred
   bytes of `text/plain` back means LFS ate it.

### Then repoint the pod

In `@livekit/react-native-webrtc`'s `livekit-react-native-webrtc.podspec`,
replace:

```ruby
s.dependency 'WebRTC-SDK', '=144.7559.10'
```

Do it as an anchored patch in `scripts/patch-webrtc-native.js` (the mobile
repo), the same way the Android gradle coordinate is swapped — a hand edit to
`node_modules` is undone by the next `yarn install`.

🔴 **That swap alone does not install anything.** Unlike gradle, where a
`maven { url }` block sits in the same file as the coordinate, CocoaPods
resolves only from Podfile-declared sources — and this pod is not in the trunk
spec repo. The Podfile declaration in `plugins/withInvestLinkWebRTC.js` is the
other half; without it the patched dependency fails with `Unable to find a
specification for InvestLinkWebRTC`, which looks like a typo rather than a
missing source. Ship the two together.
