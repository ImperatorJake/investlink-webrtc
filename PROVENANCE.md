# 144.7559.05-il1

InvestLink's WebRTC build, carrying `org.webrtc.ExternalAudioSource` so screen
audio can be published as its own track. See
`native/webrtc-external-audio/BUILD-RUNBOOK.md` in the mobile repo for why this
exists and how to rebuild it.

## Android — `webrtc-android-144.7559.05-il1.aar`

### What it is

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

### How it was built

```bash
cd native/webrtc-external-audio
./fetch.sh ~/webrtc-full
node apply-delta.js ~/webrtc-full/webrtc/src
./build.sh ~/webrtc-full
./verify-artifact.sh android ~/webrtc-full/webrtc/src/out/aar/libwebrtc.aar
```

`build.sh` passes `--webrtc-nobuild`, which despite the name still builds the
AAR — it gates only the per-arch static-library loop, which we do not publish.

### Verified, not assumed

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

### Consuming it

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


---

# iOS — `WebRTC.xcframework.zip` (144.7559.10-il1)

## What it is

| | |
|---|---|
| Upstream | `webrtc-sdk/webrtc` @ `f47af7bc965851090bef9fce9a4284f468d20a44` |
| Build harness | `webrtc-sdk/webrtc-build` tag `m144.7559.10` |
| Our delta | mobile repo commit `eeb0086`, `native/webrtc-external-audio/` |
| Delta unchanged through | `d9e8c36` — `webrtc/` and `apply-delta.js` are byte-identical at `eeb0086`, `1b65294` and `d9e8c36`, so this artifact is current at HEAD |
| Built | 2026-08-27, macOS 15 (Darwin 25.6.0), Xcode 26.6 (17F113), 8 cores |
| Size | 18,258,882 bytes (zip) |
| Published at | `ios/144.7559.10-il1/WebRTC.xcframework.zip`, a plain git blob served over raw.githubusercontent — same mechanism as the AAR |
| SHA-256 | `f444b4c5fc32f48f2f4c5d0fa700141c62d05003dfbde3768ef196cfe04a6bba` |

🔴 **A DIFFERENT upstream commit from the Android AAR, and that is correct.**
`@livekit/react-native-webrtc`'s iOS code calls ObjC APIs that only exist from
`.10` (`setPlatformVoiceProcessingAllowed:`, `platformAudioProcessingState`,
`isVoiceProcessingEnabledRequested` in `WebRTCModule+RTCAudioDeviceModule.m`),
which is why its podspec pinned `=144.7559.10` while its gradle pinned `.05`.
The disagreement is a real per-platform requirement, not drift. An earlier
attempt to unify both on `.05` built and published fine and then failed at the
first `xcodebuild` — see the README section on this.

## Slices

| identifier | architectures |
|---|---|
| `ios-arm64` | `arm64` (device) |
| `ios-arm64_x86_64-simulator` | `arm64`, `x86_64` |

**iOS only — two slices, not the stock pod's eleven.** `xcframework.sh` also
builds macOS, Mac Catalyst, tvOS and visionOS; each is a full WebRTC compile and
this app loads none of them. Skipping them cost nothing and saved roughly 12-18
hours on an 8-core machine. The consequence is that this artifact is NOT a
drop-in for a non-iOS consumer, which is why the podspec deliberately declares
no `osx.deployment_target`.

## Build flags

`apple/xcframework.sh`'s `COMMON_ARGS` verbatim, per slice, notably
`is_debug = false`, `enable_stripping = true`, `rtc_enable_symbol_export = true`,
`rtc_use_h264 = false` and `treat_warnings_as_errors = true` — our ObjC++
compiled warning-clean under that last one on the first attempt.

## How it was built

`build.apple.sh` was NOT used: it passes `--webrtc-fetch`, which runs
`git checkout -f` and `git clean -df` and would erase the delta. The steps were

```bash
# 1. fetch and sync ONLY (run.py's `apple` target build step is a no-op — see below)
python3 run.py build apple --commit 6c1aa903241e69eb2eca64caad16779351bb1ab2 \
    --webrtc-fetch --webrtc-nobuild

# 2. apply the delta AFTER the last fetch, never before
node native/webrtc-external-audio/apply-delta.js <checkout>/src

# 3. gn gen + ninja ios_framework_bundle per slice, then lipo + -create-xcframework
#    (what xcframework.sh does, restricted to the three iOS slices)

# 4. verify BEFORE publishing
./native/webrtc-external-audio/verify-artifact.sh ios <path>/WebRTC.xcframework.zip
```

Two traps worth recording, both cost time here:

- **`run.py build apple` compiles nothing.** `run.py:1197` is
  `elif args.target in ['apple', 'apple_prefixed']: pass`. It prints
  "Building for commit:" and exits 0 in seconds. All real work is in
  `apple/xcframework.sh`. `--webrtc-gen-force` is therefore inert on this target
  — harmless, because xcframework.sh gens after the delta is applied, but a bare
  `run.py build apple` looks exactly like a successful build.
- **Driving ninja by hand needs two things at once**: depot_tools on `PATH`
  (build actions shell out to `vpython3`) AND cwd at the source root (the
  depot_tools `ninja` shim resolves `third_party/ninja` relative to cwd). Miss
  either and the error names the wrong problem.

## Verified, not assumed

```
✓ RTCExternalAudioSource.h is in the framework headers
✓ ios-arm64_x86_64-simulator contains the RTCExternalAudioSource class
✓ ios-arm64 contains the RTCExternalAudioSource class
```

`WebRTC.h`, the generated umbrella header, carries
`#import <WebRTC/RTCExternalAudioSource.h>` — that is what makes
`#import <WebRTC/RTCExternalAudioSource.h>` resolve in `ILScreenAudioSink.m`,
and it is a SEPARATE failure from the class being compiled in. An earlier draft
of the delta only added the files to the compile target, which would have built
green and left the header unimportable.

The verifier's iOS path had never executed before this build, so it was proven
in both directions here: stripped of the header and given a junk binary it fails
both checks and exits 1, and with one slice of the real XCFramework gutted it
names that slice specifically.
