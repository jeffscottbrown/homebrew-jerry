class Jerry < Formula
    desc "Jerry programming language compiler"
    homepage "https://github.com/jeffscottbrown/jerry-lang"
    url "https://github.com/jeffscottbrown/jerry-lang/archive/refs/tags/v0.1.16.tar.gz"
    sha256 "1bcf9dae5335ef16632199c67f844db7d153841210c31ab16c0098fa198dc279"
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
