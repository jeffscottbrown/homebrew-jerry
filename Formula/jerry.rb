class Jerry < Formula
    desc "Jerry programming language compiler"
    homepage "https://github.com/jeffscottbrown/jerry-lang"
    url "https://github.com/jeffscottbrown/jerry-lang/archive/refs/tags/v0.4.0.tar.gz"
    sha256 "f61596558b47718f6170c130609cdf4e07821a5c709651729fd9f81c775e407c"
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
