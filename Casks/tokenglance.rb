cask "tokenglance" do
  version "0.1.1"
  sha256 "398d7af0b59b233066774680b89f4dc16c1ca0f704c31b08b352399050f7b145"

  url "https://github.com/marcel-breuer/tokenglance/releases/download/v#{version}/TokenGlance-#{version}-arm64.zip"
  name "TokenGlance"
  desc "Local token usage monitor for AI coding tools"
  homepage "https://github.com/marcel-breuer/tokenglance"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "TokenGlance.app"

  zap trash: [
    "~/Library/Application Support/TokenGlance",
    "~/Library/Caches/dev.marcelbreuer.tokenglance",
    "~/Library/Preferences/dev.marcelbreuer.tokenglance.plist",
    "~/Library/Saved Application State/dev.marcelbreuer.tokenglance.savedState",
  ]

  caveats <<~EOS
    TokenGlance is open-source software and is not signed or notarized
    through the Apple Developer Program.

    Install it with current Homebrew:

      brew install --cask marcel-breuer/tap/tokenglance

    If macOS blocks the first launch because the app is unsigned and
    unnotarized, approve TokenGlance in System Settings > Privacy & Security
    or remove the quarantine attribute for this app only:

      xattr -dr com.apple.quarantine /Applications/TokenGlance.app

    Only install releases obtained from the official TokenGlance
    repository and verify the published checksum.
  EOS
end
