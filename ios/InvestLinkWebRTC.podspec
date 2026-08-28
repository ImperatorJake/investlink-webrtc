# InvestLink's WebRTC XCFramework.
#
# Drop-in replacement for the `WebRTC-SDK` pod, adding RTCExternalAudioSource so
# screen-share audio can be published as its own track. See PROVENANCE.md.
#
# Built 2026-08-27 on macOS (Xcode 26.6) and verified with
# `verify-artifact.sh ios` — both slices carry the class and the header is
# exported from the framework umbrella. See PROVENANCE.md for checksums.
#
# iOS SLICES ONLY (device + simulator). The stock WebRTC-SDK pod vends eleven
# slices including macOS, Mac Catalyst, tvOS and visionOS; this app is iOS-only
# and building the other eight costs ~12-18h for slices nothing loads. That is
# why `s.osx.deployment_target` is NOT declared below — see the note there.
#
# Hosted exactly like the Android AAR: a plain git blob served over
# raw.githubusercontent, at a VERSION-SCOPED path. Committing it was rejected in
# an earlier draft on the grounds that an XCFramework is ~300MB — but that
# figure assumed the stock pod's eleven slices. Ours is iOS-only and 17MB,
# smaller than the 48MB AAR already committed, so the objection does not apply
# and one hosting mechanism now serves both platforms.
#
# 🔴 This file must stay a PLAIN GIT BLOB. raw.githubusercontent serves the
# POINTER TEXT for anything in Git LFS, so an LFS-tracked archive arrives as a
# few hundred bytes of pointer and fails as a corrupt zip, mentioning nothing
# about LFS. Same trap the AAR carries a warning about in the README.

Pod::Spec.new do |s|
  s.name         = 'InvestLinkWebRTC'
  s.version      = '144.7559.05-il1'
  s.summary      = 'WebRTC with ExternalAudioSource, for screen-share audio on its own track.'
  s.description  = <<-DESC
    Built from webrtc-sdk/webrtc @ 6c1aa903241e69eb2eca64caad16779351bb1ab2
    (m144.7559.05) with InvestLink's ExternalAudioSource delta applied. Replaces
    the WebRTC-SDK pod that @livekit/react-native-webrtc depends on.
  DESC
  s.homepage     = 'https://github.com/ImperatorJake/investlink-webrtc'
  s.license      = { :type => 'BSD-3-Clause' }
  s.author       = 'InvestLink'

  # Matches the deployment target the stock WebRTC-SDK pod declares. Raising
  # this would silently raise the whole app's floor.
  s.ios.deployment_target = '13.0'
  # No `s.osx.deployment_target` on purpose. The stock pod declares 10.15 and
  # ships a macOS slice; this XCFramework has none. Declaring osx support we do
  # not have would resolve cleanly and then fail at LINK time with an obscure
  # missing-architecture error. Better to be unresolvable than to be wrong.
  # If a macOS consumer ever appears, build the slice first, then add this back.

  # `main` is safe here because the PATH carries the version — same property the
  # Android maven layout relies on. Publishing a rebuild means a new
  # `ios/<version>/` directory, never overwriting this one, so a given
  # s.version always resolves to the same bytes.
  #
  # :sha256 is the iOS counterpart of the .sha1/.md5 sidecars gradle checks.
  # CocoaPods verifies it on download, so a truncated or substituted fetch fails
  # loudly here rather than as a baffling link error later.
  s.source = {
    :http => 'https://raw.githubusercontent.com/ImperatorJake/investlink-webrtc/' \
             "main/ios/#{s.version}/WebRTC.xcframework.zip",
    :sha256 => '5f0fc16dbbb823504fe8473e852ab3796aa5bec2f20c53a5ac77ebbcf82a30e7'
  }

  s.vendored_frameworks = 'WebRTC.xcframework'

  # Keep in step with the stock pod: consumers link these transitively and a
  # missing one shows up as an obscure link error rather than a clear message.
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'CoreAudio', 'CoreMedia', 'CoreVideo'
  s.libraries  = 'c++'
end
