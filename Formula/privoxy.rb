# Privoxy, built with HTTPS inspection.
#
# homebrew-core's privoxy is bottled without it: its `./configure` line passes
# neither --with-openssl nor --with-mbedtls, so FEATURE_HTTPS_INSPECTION is
# compiled out and the ca-* directives are rejected at startup with
# "Ignoring unrecognized directive 'ca-directory ...'". `otool -L` on that
# bottle links only libz and libpcre2 - no TLS library at all.
#
# Everything below is the core formula plus openssl@3 and --with-openssl.
# Keep it in sync when core bumps the version.
class Privoxy < Formula
  desc "Advanced filtering web proxy, built with HTTPS inspection"
  homepage "https://www.privoxy.org/"
  url "https://downloads.sourceforge.net/project/ijbswa/Sources/4.2.0%20%28stable%29/privoxy-4.2.0-stable-src.tar.gz"
  sha256 "6f91267f81f626c416994db89ab62f4d09246eebf4754b81186e13a18ee9028f"
  license "GPL-2.0-or-later"

  livecheck do
    url :stable
    regex(%r{url=.*?/privoxy[._-]v?(\d+(?:\.\d+)+)[._-]stable[._-]src\.t}i)
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "ca-certificates"
  depends_on "openssl@3"
  depends_on "pcre2"

  def install
    system "autoreconf", "--force", "--install", "--verbose"
    # --with-openssl is the whole point of this formula; configure reports
    # "Detected OpenSSL-compatible library. Enabling https inspection."
    system "./configure", "--with-openssl",
                          "--sysconfdir=#{pkgetc}",
                          "--localstatedir=#{var}",
                          *std_configure_args
    system "make"
    system "make", "install"
  end

  # No `service` block on purpose: the launchd job for this machine is
  # com.schretzi.privoxy, installed from MacbookSetup's privoxy role, so that
  # the label, log paths and rotation follow the same conventions as every
  # other background job here. `brew services` would install a second,
  # competing job under homebrew.mxcl.privoxy.

  test do
    # 1. It proxies at all.
    bind_address = "127.0.0.1:#{free_port}"
    (testpath/"config").write("listen-address #{bind_address}\n")
    pid = spawn sbin/"privoxy", "--no-daemon", testpath/"config"
    begin
      sleep 5
      output = shell_output("curl --head --proxy #{bind_address} https://github.com")
      assert_match "HTTP/1.1 200 Connection established", output
    ensure
      Process.kill("SIGINT", pid)
      Process.wait(pid)
    end

    # 2. It was actually built with HTTPS inspection. Without it, privoxy
    #    logs "Ignoring unrecognized directive" for every ca-* line and
    #    carries on regardless - so the absence of that message is the test.
    inspect_address = "127.0.0.1:#{free_port}"
    (testpath/"ca").mkpath
    (testpath/"ssl-config").write <<~EOS
      listen-address #{inspect_address}
      ca-directory #{testpath}/ca
      ca-cert-file cacert.crt
      ca-key-file cakey.pem
      certificate-directory #{testpath}/ca
    EOS
    log = testpath/"ssl.log"
    pid = spawn sbin/"privoxy", "--no-daemon", testpath/"ssl-config", [:out, :err] => log.to_s
    begin
      sleep 2
    ensure
      Process.kill("SIGTERM", pid)
      Process.wait(pid)
    end
    refute_match "unrecognized directive", log.read
  end
end
