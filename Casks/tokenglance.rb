cask "tokenglance" do
  version "0.1.0"
  sha256 "ca936bf0d448e0d2c9fd6d3d88d890c2ab44d19fbfe0eb3252fdd4fcc3f6edff"

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

    Install it with:

      brew install --cask --no-quarantine marcel-breuer/tap/tokenglance

    Only install releases obtained from the official TokenGlance
    repository and verify the published checksum.
  EOS
end
