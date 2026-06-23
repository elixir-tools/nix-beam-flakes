{fetchFromGitHub}: rec {
  version = "0.1.5";
  src = fetchFromGitHub {
    owner = "expert-lsp";
    repo = "expert";
    tag = "v${version}";
    hash = "sha256-QpL58+rzXCl8jT/8sbvDmDZtcWz0+ZKg47XC33EwFyE=";
  };
}
