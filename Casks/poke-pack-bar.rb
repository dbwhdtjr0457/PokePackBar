cask "poke-pack-bar" do
  version "0.11.11"
  sha256 "aa3612c362e2e8e11bd794516276af9f216360a5bfe12ec2ee0d3ab574b4c876"

  url "https://github.com/wonyangs/PokePackBar/releases/download/v#{version}/PokePackBar.zip"
  name "PokePackBar"
  desc "Turn your AI coding tokens into Pokemon card packs"
  homepage "https://github.com/wonyangs/PokePackBar"

  depends_on macos: :sonoma

  app "PokePackBar.app"

  # 내부 배포라 공증(notarization)을 하지 않는다. Gatekeeper 격리 속성을 떼어
  # 테스터가 매번 우클릭으로 열지 않게 한다.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/PokePackBar.app"]
  end

  zap trash: [
    "~/Library/Application Support/PokePackBar",
    "~/Library/Logs/PokePackBar.log",
  ]
end
