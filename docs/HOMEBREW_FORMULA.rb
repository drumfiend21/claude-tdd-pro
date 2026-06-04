# Homebrew formula for claude-tdd-pro. Per docs/SCALE_TARGET.md
# Tier 2 → Tier 3 distribution: brew install drumfiend21/tdd-pro/claude-tdd-pro.
#
# To publish:
#   gh repo create drumfiend21/homebrew-tdd-pro --public
#   cp docs/HOMEBREW_FORMULA.rb /path/to/homebrew-tdd-pro/Formula/claude-tdd-pro.rb
#   git push
#
# After publish:
#   brew tap drumfiend21/tdd-pro
#   brew install claude-tdd-pro

class ClaudeTddPro < Formula
  desc "Rubric runner + drift gates + fitness functions for AI-assisted code review"
  homepage "https://github.com/drumfiend21/claude-tdd-pro"
  license "Apache-2.0"
  version "0.4.0"
  url "https://github.com/drumfiend21/claude-tdd-pro/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256_FOR_v0_4_0_TARBALL"

  depends_on "bash"
  depends_on "node"
  depends_on "ruby"
  depends_on "git"

  def install
    libexec.install Dir["*"]
    (bin/"tdd-pro").write <<~EOS
      #!/usr/bin/env bash
      export CLAUDE_PLUGIN_ROOT="#{libexec}"
      exec bash "#{libexec}/scripts/install.sh" "$@"
    EOS
    chmod 0755, bin/"tdd-pro"
  end

  test do
    system bin/"tdd-pro", "version"
  end
end
