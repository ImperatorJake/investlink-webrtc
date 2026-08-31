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


---

# iOS — `WebRTC.xcframework.zip` (144.7559.10-il2)

## What it is

| | |
|---|---|
| Upstream | `webrtc-sdk/webrtc` @ `f47af7bc965851090bef9fce9a4284f468d20a44` (unchanged from `-il1`) |
| Build harness | `webrtc-sdk/webrtc-build` tag `m144.7559.10` |
| Our delta | mobile repo commit `92698760a2aa1558deeae96e837891f351f1268d`, branch `claude/screen-share-audio-followups` |
| Built | 2026-08-30, macOS 26.6.2 (Darwin 25.6.0), Apple M2, 8 cores, Xcode 26.6 (17F113) |
| Size | 18,258,187 bytes (zip) |
| Published at | `ios/144.7559.10-il2/WebRTC.xcframework.zip` |
| SHA-256 | `5e8a3401c6722451ead3e169cf461813edc302774e9f2d6c36b7ff58fa2c453d` |

Same upstream commit as `-il1`; only our delta changed. The `-il2` suffix is our
build number against that upstream version, which is exactly what it is for.

## Why `-il2` exists

Two on-device crashes (mobile build 66, 2026-08-29) died on
`RTC_CHECK_RUNS_SERIALIZED` in `AudioSendStream::SendAudioData`
(`audio/audio_send_stream.cc:393`). The send stream fed by our
`ExternalAudioSource` was **also** registered for the ADM microphone fan-out, so
the mic capture thread and our push thread raced into a single stream that
asserts it is only ever touched by one.

The fix adds a per-source `external_pcm_source` flag on `AudioOptions`, which
`ExternalAudioSource` sets on itself. `WebRtcVoiceEngine` forwards it per stream
to `AudioSendStream::SetExternallyFed`, and an externally-fed stream then skips
`AddSendingStream`/`RemoveSendingStream` in `Start()`/`Stop()`. One producer per
stream, which is what the check was always asking for.

That is 11 new anchored edits in `apply-delta.js` (the "ADM fan-out opt-out"
block) on top of the original 5, plus one line in
`webrtc/pc/external_audio_source.cc`. All 16 applied cleanly to a fresh
`f47af7bc` checkout — none reported as already applied.

✅ **Resolved the same day.** When this entry was written Android was still at
`144.7559.05-il1`, carrying the identical latent race, because the AAR builds
only on Linux and that rebuild was deferred. It happened hours later — see the
`webrtc-android 144.7559.05-il2` entry at the end of this file. Both platforms
now carry the fan-out opt-out, and `scripts/webrtc-version.js` pins `-il2` for
both.

Worth keeping as a record of the shape rather than editing away: a fix that
lands on one platform first leaves the other quietly broken, and the only thing
standing between that and a shipped crash is writing down which half is done.

## Slices

Identical to `-il1`: `ios-arm64` (device) and `ios-arm64_x86_64-simulator`.
iOS only — the other eight slices `xcframework.sh` builds are still skipped, so
this artifact is still not a drop-in for a non-iOS consumer and the podspec
still declares no `osx.deployment_target`.

## Build flags

`apple/xcframework.sh`'s `COMMON_ARGS` verbatim, per slice — notably
`is_debug = false`, `enable_stripping = true`, `rtc_enable_symbol_export = true`,
`rtc_use_h264 = false` and `treat_warnings_as_errors = true`. The new C++ in
`audio/`, `media/engine/` and `api/` compiled warning-clean under that last one.

## How it was built

```bash
# 1. fetch and sync ONLY — `run.py build apple` compiles nothing (run.py:1199 is `pass`)
python3 run.py build apple --commit f47af7bc965851090bef9fce9a4284f468d20a44 \
    --webrtc-fetch --webrtc-nobuild \
    --webrtc-source-dir $WORK/webrtc --source-dir $WORK/_source --build-dir $WORK/_build

# 2. apply the delta AFTER the last fetch, never before
node native/webrtc-external-audio/apply-delta.js $WORK/webrtc/src

# 3. gn gen + ninja ios_framework_bundle for the three iOS slices, then
#    lipo + xcodebuild -create-xcframework + zip — xcframework.sh restricted
#    to iOS, everything else verbatim

# 4. verify BEFORE publishing
./native/webrtc-external-audio/verify-artifact.sh ios $WORK/out-ios/WebRTC.xcframework.zip
```

### A new trap, paid for here

**A freshly cloned `depot_tools` is not bootstrapped, and its `gn`/`ninja` are
only shims.** The first slice build died immediately on

```
python3_bin_reldir.txt not found. need to initialize depot_tools by
running gclient, update_depot_tools or ensure_bootstrap.
```

`run.py`'s fetch path drives `gclient` directly and never bootstraps the shims,
so the fetch succeeds and leaves `gn` unusable — which only matters because the
iOS path drives the slice build by hand. `depot_tools/ensure_bootstrap` fixes
it. This joins the existing "driving ninja by hand needs depot_tools on PATH and
cwd at the source root" note: it is a THIRD prerequisite for the same step.

Worth repeating that the failing run still exited 0 through a shell wrapper
whose last command was `tail`. The build log said what happened; the exit code
did not.

## Verified, not assumed

```
iOS artifact: .../out-ios/WebRTC.xcframework.zip
  ✓ RTCExternalAudioSource.h is in the framework headers
  ✓ ios-arm64_x86_64-simulator contains the RTCExternalAudioSource class
  ✓ ios-arm64 contains the RTCExternalAudioSource class

OK — the artifact carries ExternalAudioSource.
```

`verify-artifact.sh` proves the ORIGINAL delta reached the binary, but it would
pass just as happily on an `-il1` rebuild — it knows nothing about the fan-out
fix. So the fix itself was checked directly: `external_pcm_source` reaches the
binary as a string via `AudioOptions::ToString`, and it is present in both
slices.

```
$ strings WebRTC.xcframework/ios-arm64/WebRTC.framework/WebRTC | grep -c external_pcm_source
1
$ strings WebRTC.xcframework/ios-arm64_x86_64-simulator/WebRTC.framework/WebRTC | grep -c external_pcm_source
2
```

Two in the simulator slice and one in the device slice is the expected shape,
not a discrepancy: the simulator binary is a fat `arm64 + x86_64` file and each
architecture contributes its own copy of the string.

## webrtc-android 144.7559.05-il2 (2026-08-30)

Built on the WSL box (Linux; the AAR builds nowhere else) from
webrtc-sdk/webrtc @ 6c1aa903241e69eb2eca64caad16779351bb1ab2 (m144.7559.05)
with the mobile repo's delta at commit 31f28cf (branch
claude/screen-share-audio-followups) — the same "ADM fan-out opt-out" delta as
the iOS -il2: a stream fed by ExternalAudioSource opts out of the microphone
fan-out (external_pcm_source), fixing the fatal two-producer race in
AudioSendStream::SendAudioData seen twice on iOS build 66 (2026-08-29). Android
had the identical latent race, unexercised.

- fetch.sh → apply-delta.js (8 copies + all EDITS incl. the 11 fan-out edits,
  every one applied fresh) → build.sh (4 ABIs) → verify-artifact.sh android:
  ExternalAudioSource in classes.jar, all 5 JNI entry points in all 4 ABIs.
- Fix-presence check: `strings jni/arm64-v8a/libjingle_peerconnection_so.so |
  grep -c external_pcm_source` → 1.
- SHA-256 (aar): 8bae0b42406a592638b5c2ee14575bd639e2c262a8900a1eabdab2010d66bca0
