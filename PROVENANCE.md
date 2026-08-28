# libwebrtc-144.7559.05-il1.aar

InvestLink's WebRTC build, carrying `org.webrtc.ExternalAudioSource` so screen
audio can be published as its own track. See
`native/webrtc-external-audio/BUILD-RUNBOOK.md` in the mobile repo for why this
exists and how to rebuild it.

## What it is

| | |
|---|---|
| Upstream | `webrtc-sdk/webrtc` @ `6c1aa903241e69eb2eca64caad16779351bb1ab2` |
| Build harness | `webrtc-sdk/webrtc-build` tag `m144.7559.05` |
| Our delta | mobile repo commit `1b65294`, `native/webrtc-external-audio/` |
| Built | 2026-08-27, Ubuntu 24.04 (WSL2), 20 cores |
| Size | 48,554,378 bytes |
| SHA-256 | `f745e0af037bf8547115c03d54e8e1a245975479fd678c7a594065439ffbf135` |

ABIs: `armeabi-v7a`, `arm64-v8a`, `x86_64`, `x86` — all four, matching what the
stock `io.github.webrtc-sdk:android` artifact ships.

The `-il1` suffix is our build number against that upstream version. Bump it for
any rebuild of the SAME upstream commit; change the version part only when the
upstream commit changes.

## How it was built

```bash
cd native/webrtc-external-audio
./fetch.sh ~/webrtc-full
node apply-delta.js ~/webrtc-full/webrtc/src
./build.sh ~/webrtc-full
./verify-artifact.sh android ~/webrtc-full/webrtc/src/out/aar/libwebrtc.aar
```

`build.sh` passes `--webrtc-nobuild`, which despite the name still builds the
AAR — it gates only the per-arch static-library loop, which we do not publish.

## Verified, not assumed

```
✓ org.webrtc.ExternalAudioSource is in classes.jar
✓ arm64-v8a exports all 5 JNI entry points
✓ armeabi-v7a exports all 5 JNI entry points
✓ x86 exports all 5 JNI entry points
✓ x86_64 exports all 5 JNI entry points
```

A green build proves nothing about an artifact's contents: a `BUILD.gn`
insertion can land in the wrong target and produce a library that compiles
perfectly with none of our code in it. `verify-artifact.sh` is what closes that
gap, and it is proven in both directions — it rejects the stock upstream AAR.

## Consuming it

Replace, in `@livekit/react-native-webrtc`'s `android/build.gradle`:

```gradle
api 'io.github.webrtc-sdk:android:144.7559.05'
```

with this artifact's coordinate, served from a static maven layout in a public
repo (EAS CI needs an unauthenticated HTTPS fetch). The swap itself belongs in
`scripts/patch-webrtc-native.js` as an anchored patch, so it survives
`yarn install` and fails loudly if upstream moves the line.

⚠️ iOS pins a DIFFERENT version — `WebRTC-SDK =144.7559.10` in the podspec.
Building our own is the opportunity to close that gap: build one upstream commit
and use it for both platforms.
