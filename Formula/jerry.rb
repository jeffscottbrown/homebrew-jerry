class Jerry < Formula
    desc "Jerry programming language compiler"
    homepage "https://github.com/jeffscottbrown/jerry-lang"
    url "https://github.com/jeffscottbrown/jerry-lang/archive/refs/tags/v0.5.1.tar.gz"
    sha256 "3a494e3c65bd3482cdd537d86ca39403ebbe41bece684f6d088abee129338804"
    license "MIT"
    head "https://github.com/jeffscottbrown/jerry-lang.git", branch: "main"

    depends_on "go" => :build

    def install
      system "go", "build",
        *std_go_args(ldflags: "-s -w -X main.Version=#{version}"),
        "./cmd/jerry"

      # Pre-compile the C runtime to a static archive.
      # The jerry binary discovers it at <prefix>/lib/jerry_runtime.a and uses
      # it directly, avoiding the go:embed extraction on every compilation.
      system ENV.cc, "-O2", "-c", "runtime/src/runtime.c",
             "-Iruntime/src", "-o", "jerry_runtime.o"
      system "ar", "rcs", lib/"jerry_runtime.a", "jerry_runtime.o"
    end

    test do
      (testpath/"hello.jer").write <<~EOS
        fn main() {
          print("Hello from Homebrew!");
        }
      EOS
      assert_match "Hello from Homebrew!", shell_output("#{bin}/jerry run hello.jer")
    end
  end
