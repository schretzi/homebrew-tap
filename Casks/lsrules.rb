# Hand-written for v0.1.0 and v0.2.0, when LittleSnitchRules had no
# HOMEBREW_TAP_TOKEN and goreleaser's cask publish got a 401. The secret
# exists now, so the next release overwrites this file like every other cask
# here - do not hand-edit it from here on. That path has not run yet, though:
# it is proven by the next release, not by the secret being present.
cask "lsrules" do
  version "0.2.0"

  on_macos do
    on_arm do
      sha256 "e6333c39746f181b1e08eec2cee2e908532e794621a4ff5620634eed554b9109"
      url "https://github.com/schretzi/LittleSnitchRules/releases/download/v#{version}/lsrules_#{version}_darwin_arm64.tar.gz"
    end
    on_intel do
      sha256 "da6f4a4a96303475c67c7fe7c2cbba6e0ac63ddf1285de601f78ff656cd0e316"
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
