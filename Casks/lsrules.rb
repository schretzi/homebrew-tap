# Written by hand for v0.1.0 because the LittleSnitchRules repository has no
# HOMEBREW_TAP_TOKEN secret yet, so goreleaser's cask publish got a 401. Once
# that secret exists this file is generated like the others - do not hand-edit
# it after that.
cask "lsrules" do
  version "0.1.0"

  on_macos do
    on_arm do
      sha256 "7d16bec3e8ac47d0f9e0caaa2327262d0200afd6386777db915720c75dc3a6fe"
      url "https://github.com/schretzi/LittleSnitchRules/releases/download/v#{version}/lsrules_#{version}_darwin_arm64.tar.gz"
    end
    on_intel do
      sha256 "55c76c622e8b7e3a6b42f41238c5c56df5eb570979a1f8415d73d6c54466be66"
      url "https://github.com/schretzi/LittleSnitchRules/releases/download/v#{version}/lsrules_#{version}_darwin_amd64.tar.gz"
    end
  end

  name "lsrules"
  desc "Serve Little Snitch rule groups over HTTPS from this machine"
  homepage "https://github.com/schretzi/LittleSnitchRules"

  livecheck do
    skip "Auto-generated on release."
  end

  binary "lsrules"

  caveats <<~EOS
    This only installs the binary. It needs a certificate - Little Snitch
    subscribes over HTTPS and nothing else - which MacbookSetup's local_ca
    role issues:

      ansible-playbook site.yml --tags local_ca --ask-become-pass

    Then:

      lsrules config init
      lsrules config validate
      lsrules service install
  EOS

  postflight do
    if OS.mac?
      # The release binaries are not notarized, so Gatekeeper would
      # otherwise refuse to run them after a browser-less download.
      system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{staged_path}/lsrules"]
    end
  end

  uninstall_preflight do
    # The LaunchAgent plist references this binary by absolute path, so
    # leaving it loaded would make launchd retry a deleted executable
    # forever. Boot it out and remove the plist first.
    system_command "#{staged_path}/lsrules", args: ["service", "uninstall"], must_succeed: false
  end

  # The rule groups themselves are not listed: they live in a git checkout
  # this only reads, and deleting someone's repository because they
  # uninstalled a server would be unforgivable.
  zap trash: [
    "~/.config/lsrules",
    "~/Library/Logs/lsrules.log",
    "~/Library/Logs/lsrules.err.log",
    "~/Library/LaunchAgents/com.schretzi.lsrules.plist",
  ]
end
