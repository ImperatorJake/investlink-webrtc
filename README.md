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
ios/            podspec for the XCFramework (published as a Release asset)
checksums.sh    regenerate .sha1/.md5 sidecars after changing any artifact
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

Not built yet. The podspec in `ios/` is a template pointing at a Release asset
that does not exist; it needs a Mac.

## 🔴 Do not enable Git LFS on this repo

Gradle fetches the AAR through `raw.githubusercontent.com`. If the AAR is stored
in LFS, that URL returns the **pointer text file**, not the binary — and gradle
fails with a confusing "not a valid zip" or checksum error rather than anything
that points at LFS. The artifact must be a plain git blob.

That is why the repo tolerates a 48MB binary in history and why the iOS
XCFramework goes to Release assets instead: assets are fetched on demand and
never enter git history.

## Versioning

`<upstream-version>-il<n>` — e.g. `144.7559.05-il1`.

- Change the version part only when the **upstream commit** changes.
- Bump `il<n>` for a rebuild of the same upstream commit (a fix in our delta).

Both platforms should be built from the SAME upstream commit. Note that today
the pod and the gradle dependency disagree — iOS pins `144.7559.10` and Android
`144.7559.05` — and building our own is the chance to close that.

## Adding an Android artifact

1. Build and verify it (`verify-artifact.sh` in the mobile repo — a green build
   proves nothing about an artifact's contents).
2. Drop the AAR into `maven/com/investlink/webrtc-android/<version>/` as
   `webrtc-android-<version>.aar`, with a matching `.pom`.
3. Update `maven-metadata.xml`.
4. Run `./checksums.sh`.
5. Record upstream commit, harness tag, delta commit SHA and checksums in
   `PROVENANCE.md`. Without it the next upgrade is archaeology.

## Adding the iOS artifact — not done yet

The XCFramework has to be built on a Mac. Start from
`native/webrtc-external-audio/BUILD-RUNBOOK.md` and
`notes/ios-screen-audio-handoff.md` in the mobile repo; this section is only
about publishing what comes out.

**It goes to a GitHub Release asset, NOT into git.** At roughly 300MB an
XCFramework in history would be paid for by every clone of this repo forever,
whereas release assets are fetched on demand. The Android AAR is committed only
because gradle needs a maven layout over plain HTTPS, and 48MB is a tolerable
price for that.

1. Build it, then verify — the iOS half of the verifier checks that the header
   is exported from the framework and that each slice's binary really contains
   the class, which are different failures:

   ```bash
   ./native/webrtc-external-audio/verify-artifact.sh ios <path-to-xcframework-or-zip>
   ```

2. Zip it as `WebRTC.xcframework.zip`.
3. Create a release tagged **`ios-<version>`** — e.g. `ios-144.7559.05-il1` —
   and attach the zip. The tag shape matters: `ios/InvestLinkWebRTC.podspec`
   builds its download URL from `ios-#{s.version}`.
4. In `ios/InvestLinkWebRTC.podspec`, remove the `TODO` comment and confirm
   `s.version` matches the tag. Check the deployment targets still match the
   stock `WebRTC-SDK` pod — raising them silently raises the whole app's floor.
5. Add an iOS section to `PROVENANCE.md`: upstream commit, harness tag, delta
   commit SHA, Xcode version, and the zip's SHA-256.
6. Sanity-check the published URL actually serves the binary before wiring the
   pod up:

   ```bash
   curl -sSIL <release-asset-url> | grep -iE "^(HTTP|content-length|content-type)"
   ```

   That is the same check that proved the Android path — fetching the exact URL
   the build tool will use, rather than trusting that it works.

### Then repoint the pod

In `@livekit/react-native-webrtc`'s `livekit-react-native-webrtc.podspec`,
replace:

```ruby
s.dependency 'WebRTC-SDK', '=144.7559.10'
```

Do it as an anchored patch in `scripts/patch-webrtc-native.js` (the mobile
repo), the same way the Android gradle coordinate is swapped — a hand edit to
`node_modules` is undone by the next `yarn install`.

⚠️ Note that line says **.10** while Android pins **.05**. They should be built
from the SAME upstream commit; use `144.7559.05` / `6c1aa903…` for both.
