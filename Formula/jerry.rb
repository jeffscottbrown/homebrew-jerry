class Jerry < Formula
  desc "Jerry programming language compiler"
  homepage "https://github.com/jeffscottbrown/jerry-lang"
  url "https://github.com/jeffscottbrown/jerry-lang/archive/refs/tags/v0.8.7.tar.gz"
  sha256 "d58f7a5087fc4f5e6c7c8d18dcc3fa07b8b8567e05c105430cdb093d7a5103aa"
  license "MIT"
  head "https://github.com/jeffscottbrown/jerry-lang.git", branch: "main"

  # Seed compiler used to bootstrap jerry-compiler from source.
  # Each release's formula points to the previous release's binaries.
  on_arm do
    resource "jerry-compiler-seed" do
      url "https://github.com/jeffscottbrown/jerry-lang/releases/download/v0.8.7/jerry-macos-arm64.tar.gz"
      sha256 "a71d8af7e5ccdbc0e7e4877d9d74db059efd178212a884aac2826a1f63cc34e0"
    end
  end

  on_intel do
    resource "jerry-compiler-seed" do
      url "https://github.com/jeffscottbrown/jerry-lang/releases/download/v0.8.7/jerry-macos-x86_64.tar.gz"
      sha256 "c7c7846f9d649a54b09f907d7a178093cb978df23dd8b48c5eaa66edf7c0faeb"
    end
  end

  def install
    # Build the C runtime static archive.
    arch_flag = Hardware::CPU.arm? ? ["-arch", "arm64"] : ["-arch", "x86_64"]
    lib.mkpath
    system ENV.cc, "-O2", *arch_flag, "-c", "runtime/src/runtime.c",
           "-Iruntime/src", "-o", "jerry_runtime.o"
    system "ar", "rcs", lib/"jerry_runtime.a", "jerry_runtime.o"

    # Install stdlib .jer files.
    (pkgshare/"stdlib").install Dir["stdlib/*.jer"]

    env = {
      "JERRY_RUNTIME" => (lib/"jerry_runtime.a").to_s,
      "JERRY_STDLIB"  => (pkgshare/"stdlib").to_s,
    }

    # Extract the seed jerry-compiler from the previous release and use it
    # to compile jerry-compiler from source.
    resource("jerry-compiler-seed").stage do
      cp "jerry-compiler", buildpath/"jerry-compiler-seed"
    end
    chmod "+x", buildpath/"jerry-compiler-seed"

    with_env(env) do
      system "./jerry-compiler-seed", "self-host/", "-o", "jerry-compiler"
    end

    # Build all Jerry tools using the freshly compiled compiler.
    with_env(env) do
      system "./jerry-compiler", "cmd/jerry-test/",   "-o", "jerry-test"
      system "./jerry-compiler", "cmd/jerry-create/", "-o", "jerry-create"
      system "./jerry-compiler", "cmd/jerry-sweep/",  "-o", "jerry-sweep"
      system "./jerry-compiler", "cmd/jerry-get/",    "-o", "jerry-get"
      system "./jerry-compiler", "cmd/jerry-lsp/",    "-o", "jerry-lsp"

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
    ENV["JERRY_STDLIB"]   = (pkgshare/"stdlib").to_s
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
