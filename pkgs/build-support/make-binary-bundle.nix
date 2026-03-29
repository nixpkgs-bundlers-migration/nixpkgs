# For documentation please see ...
{
  nix-user-chroot,
  fakedir,
  arx,
  fakedir,
  lib,
  stdenv,
  writeScript,
  emptyDirectory,
  bintools-unwrapped,
  bash,
}:
{
  contents, # This requires a drv inputed
  run,
}
let
  # hack to use when /nix/store is not available
  nix-user-chroot-override = nix-user-chroot.overrideAttrs {
    postFixup = ''
      exe=$out/bin/nix-user-chroot
      patchelf \
        --set-interpreter .$(patchelf --print-interpreter $exe) \
        --set-rpath $(patchelf --print-rpath $exe | sed 's|/nix/store/|./nix/store/|g') \
        $exe
    '';
  };


  programPath = lib.getExe contents;
  startup-script = if stdenv.hostPlatform.isLinux then writeScript "startup" ''
    #!/usr/bin/env bash
    cd ''${TMPX_RESTORE_PWD}
    exec ${lib.getExe nix-user-chroot} -- "${programPath} $0" "$@"
  '' else writeScript ''
    #!/usr/bin/env bash
    # use absolute paths so the environment variables don't get reinterpreted after a cd
    __TMPX_DAT_PATH=$(pwd)
    cd "''${TMPX_RESTORE_PWD}"
    export DYLD_INSERT_LIBRARIES="''${__TMPX_DAT_PATH}/lib/libfakedir.dylib"
    export FAKEDIR_PATTERN=/nix
    export FAKEDIR_TARGET="''${__TMPX_DAT_PATH}/nix"

    # make sure the fakedir libraries are loaded by running the command in bash within the bottle
    cmd="$(cat <<-EOH
      ''${__TMPX_DAT_PATH}${programPath}
    EOH
    )"
    args="$@"
    exec "''${__TMPX_DAT_PATH}/${bash}/bin/bash" -c "$cmd $args"
  '';


in
{}
