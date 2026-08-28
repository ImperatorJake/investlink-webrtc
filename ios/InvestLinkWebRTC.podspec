# InvestLink's WebRTC XCFramework.
#
# Drop-in replacement for the `WebRTC-SDK` pod, adding RTCExternalAudioSource so
# screen-share audio can be published as its own track. See PROVENANCE.md.
#
# ⚠️  NOT YET BUILT. The XCFramework has to be produced on a Mac — see
# native/webrtc-external-audio/BUILD-RUNBOOK.md and
# notes/ios-screen-audio-handoff.md in the mobile repo. Until then this podspec
# is a template: the URL below points at a release asset that does not exist.
#
# Publishing an XCFramework as a Release ASSET rather than committing it is
# deliberate — a ~300MB binary in git history would be paid for by every clone
# of this repo, whereas release assets are fetched only on demand. (The Android
# AAR is committed because gradle needs a maven layout over plain HTTPS, and at
# 48MB that is a tolerable trade.)

Pod::Spec.new do |s|
  s.name         = 'InvestLinkWebRTC'
  s.version      = '144.7559.05-il1'
  s.summary      = 'WebRTC with ExternalAudioSource, for screen-share audio on its own track.'
  s.description  = <<-DESC
    Built from webrtc-sdk/webrtc @ 6c1aa903241e69eb2eca64caad16779351bb1ab2
    (m144.7559.05) with InvestLink's ExternalAudioSource delta applied. Replaces
    the WebRTC-SDK pod that @livekit/react-native-webrtc depends on.
  DESC
  s.homepage     = 'https://github.com/InvestlinkSocial/investlink-webrtc'
  s.license      = { :type => 'BSD-3-Clause' }
  s.author       = 'InvestLink'

  # Matches the deployment targets the stock WebRTC-SDK pod declares. Raising
  # these would silently raise the whole app's floor.
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  # TODO: fill in once the release exists. The tag should match s.version.
  s.source = {
    :http => 'https://github.com/InvestlinkSocial/investlink-webrtc/releases/download/' \
             "ios-#{s.version}/WebRTC.xcframework.zip"
  }

  s.vendored_frameworks = 'WebRTC.xcframework'

  # Keep in step with the stock pod: consumers link these transitively and a
  # missing one shows up as an obscure link error rather than a clear message.
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'CoreAudio', 'CoreMedia', 'CoreVideo'
  s.libraries  = 'c++'
end
