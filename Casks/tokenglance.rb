cask "tokenglance" do
  version "0.1.1"
  sha256 "698730c512c1b04f4193cfe79f8cae2d28ebde75743791bb7f8481ef2e6534ce"

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
