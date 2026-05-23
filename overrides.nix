{
  pkgs,
  lib,
}: final: prev: {
  # Native deps for voice extras
  sounddevice = prev.sounddevice.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [pkgs.portaudio];
    postFixup = ''
      patchelf --set-rpath ${pkgs.portaudio}/lib $out/lib/python*/site-packages/sounddevice*.so 2>/dev/null || true
    '';
  });

  # faster-whisper depends on libsndfile via soundfile
  soundfile = prev.soundfile.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [pkgs.libsndfile];
    postFixup = ''
      patchelf --set-rpath ${pkgs.libsndfile.out}/lib $out/lib/python*/site-packages/_soundfile_data/*.so 2>/dev/null || true
    '';
  });
}
