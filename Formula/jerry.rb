class Jerry < Formula
    desc "Jerry programming language compiler"
    homepage "https://github.com/jeffscottbrown/jerry-lang"
    url "https://github.com/jeffscottbrown/jerry-lang/archive/refs/tags/v0.8.0.tar.gz"
    sha256 "50ede265dc09aa4a6a8b9178db21ec415d87946ebb251082a61e1bd92ea06374"
    license "MIT"
    head "https://github.com/jeffscottbrown/jerry-lang.git", branch: "main"

    depends_on "go" => :build

    def install
      # Build the C runtime static archive.
      arch_flag = Hardware::CPU.arm? ? ["-arch", "arm64"] : ["-arch", "x86_64"]
      lib.mkpath
      system ENV.cc, "-O2", *arch_flag, "-c", "runtime/src/runtime.c",
             "-Iruntime/src", "-o", "jerry_runtime.o"
      system "ar", "rcs", lib/"jerry_runtime.a", "jerry_runtime.o"

      # Install stdlib .jer files.
      (share/"jerry"/"stdlib").install Dir["stdlib/*.jer"]

      env = {
        "JERRY_RUNTIME" => (lib/"jerry_runtime.a").to_s,
        "JERRY_STDLIB"  => (share/"jerry"/"stdlib").to_s,
      }

      # Build jerry-lsp and jerry-get (still Go; need HTTP/LSP not yet in Jerry).
      with_env("CGO_ENABLED" => "0") do
        system "go", "build", "-o", "jerry-lsp", "./cmd/jerry-lsp"
        system "go", "build", "-o", "jerry-get", "./cmd/jerry-get"
      end

      # Bootstrap jerry-compiler: download the pre-built binary from this release,
      # use it to emit IR for self-host/, then compile with clang.
      # (Homebrew installs from a source tarball, not a git clone, so we can't
      # use git checkout to restore the old Go codegen.)
      os   = Hardware::CPU.arm? ? "macos-arm64" : "macos-x86_64"
      seed_url = "https://github.com/jeffscottbrown/jerry-lang/releases/download/#{version}/jerry-#{os}.tar.gz"
      system "curl", "-fsSL", seed_url, "-o", "seed.tar.gz"
      system "tar", "xzf", "seed.tar.gz", "jerry-compiler"
      system "chmod", "+x", "jerry-compiler"
      mv "jerry-compiler", "jerry-compiler-seed"

      with_env(env) do
        self_host_srcs = Dir["self-host/*.jer"].reject { |f| f.end_with?("_test.jer") }.sort
        system "./jerry-compiler-seed", *self_host_srcs, "--ir", :out => "self-host-bootstrap.ll"
      end
      target_flag = Hardware::CPU.arm? ? [] : ["-target", "x86_64-apple-darwin"]
      system ENV.cc, *target_flag, "-O0", "self-host-bootstrap.ll",
             lib/"jerry_runtime.a", "-o", "jerry-compiler", "-lm"

      # Build jerry-test, jerry-create, jerry-sweep, and the main dispatcher.
      with_env(env) do
        system "./jerry-compiler", "cmd/jerry-test/",   "-o", "jerry-test"
        system "./jerry-compiler", "cmd/jerry-create/", "-o", "jerry-create"
        system "./jerry-compiler", "cmd/jerry-sweep/",  "-o", "jerry-sweep"

        File.write("cmd/jerry-main/version.jer",
          "fn jerry_version(): string { return \"#{version}\"; }")
        system "./jerry-compiler", "cmd/jerry-main/", "-o", "jerry-native"
        File.write("cmd/jerry-main/version.jer",
          "fn jerry_version(): string { return \"dev\"; }")
      end

      bin.install "jerry-native" => "jerry"
      bin.install "jerry-compiler"
      bin.install "jerry-test"
      bin.install "jerry-create"
      bin.install "jerry-sweep"
      bin.install "jerry-lsp"
      bin.install "jerry-get"
    end

    test do
      ENV["JERRY_RUNTIME"]  = (lib/"jerry_runtime.a").to_s
      ENV["JERRY_STDLIB"]   = (share/"jerry"/"stdlib").to_s
      ENV["JERRY_COMPILER"] = (bin/"jerry-compiler").to_s
      ENV["JERRY_TEST"]     = (bin/"jerry-test").to_s
      ENV["JERRY_CREATE"]   = (bin/"jerry-create").to_s
      ENV["JERRY_SWEEP"]    = (bin/"jerry-sweep").to_s
      ENV["JERRY_LSP"]      = (bin/"jerry-lsp").to_s
      ENV["JERRY_GET"]      = (bin/"jerry-get").to_s

      assert_match version.to_s, shell_output("#{bin}/jerry --version")

      (testpath/"hello.jer").write <<~EOS
        fn main() {
          print("Hello from Homebrew!");
        }
      EOS
      assert_match "Hello from Homebrew!", shell_output("#{bin}/jerry run hello.jer")
    end
  end
