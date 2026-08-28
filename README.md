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

## Adding an artifact

1. Build and verify it (`verify-artifact.sh` in the mobile repo — a green build
   proves nothing about an artifact's contents).
2. Drop the AAR into `maven/com/investlink/webrtc-android/<version>/` as
   `webrtc-android-<version>.aar`, with a matching `.pom`.
3. Update `maven-metadata.xml`.
4. Run `./checksums.sh`.
5. Record upstream commit, harness tag, delta commit SHA and checksums in
   `PROVENANCE.md`. Without it the next upgrade is archaeology.
