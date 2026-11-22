# Version and sha256 are updated by scripts/publish-release.sh for each release.
cask "llm-budget-tracker" do
  version "0.1.1"
  sha256 "b725352ac9b35ca5f1b05edb416f99e911581cfa8c4a2c1fc9fca356224b4264"

  url "https://git.krohn.io/api/v4/projects/karsten%2Fllm-budget-tracker/packages/generic/llm-budget-tracker/#{version}/LLMBudgetTracker-#{version}.dmg"
  name "LLM Budget Tracker"
  desc "Menu bar app showing the budget of a LiteLLM proxy"
  homepage "https://git.krohn.io/karsten/llm-budget-tracker"

  livecheck do
    url "https://git.krohn.io/api/v4/projects/karsten%2Fllm-budget-tracker/releases/permalink/latest"
    strategy :json do |json|
      json["tag_name"]&.delete_prefix("v")
    end
  end

  depends_on macos: :tahoe

  app "LLMBudgetTracker.app"

  zap trash: "~/Library/Preferences/io.krohn.llm-budget-tracker.plist"

  caveats <<~EOS
    The app is not notarized, so macOS blocks the first launch. Allow it once under
    System Settings → Privacy & Security → Open Anyway, or remove the quarantine flag:
      xattr -dr com.apple.quarantine #{appdir}/LLMBudgetTracker.app
  EOS
end
