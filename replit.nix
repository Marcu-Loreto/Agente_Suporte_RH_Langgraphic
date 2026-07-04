# Ambiente Nix do Replit — Assistente Virtual de RH
# Fornece Python e bibliotecas de sistema necessárias ao ChromaDB/onnxruntime.
{ pkgs }: {
  deps = [
    pkgs.python311
    pkgs.python311Packages.pip
    # Bibliotecas nativas usadas por numpy/onnxruntime/chromadb
    pkgs.stdenv.cc.cc.lib
    pkgs.glibcLocales
  ];

  env = {
    # Garante que libs nativas (ex.: libstdc++) sejam encontradas em runtime.
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
      pkgs.stdenv.cc.cc.lib
    ];
    LANG = "pt_BR.UTF-8";
    PYTHONBIN = "${pkgs.python311}/bin/python3.11";
  };
}
