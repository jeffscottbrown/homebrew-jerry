class Jerry < Formula
    desc "Jerry programming language compiler"
    homepage "https://github.com/jeffscottbrown/jerry-lang"
    url "https://github.com/jeffscottbrown/jerry-lang/archive/refs/tags/v0.1.11.tar.gz"
    sha256 "f46ab45aaf63f83e8994f7fffb7597814aea0726e2d89f40701c65e73bd1e9b3"
    license "MIT"
    head "https://github.com/jeffscottbrown/jerry-lang.git", branch: "main"

    depends_on "go" => :build

    def install
      system "go", "build",
        *std_go_args(ldflags: "-s -w -X main.Version=#{version}"),
        "./cmd/jerry"
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
