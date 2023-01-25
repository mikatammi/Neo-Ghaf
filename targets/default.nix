{
  self,
  nixos-generators,
  microvm,
  jetpack-nixos,
}: {
  packages.x86_64-linux.vm = nixos-generators.nixosGenerate {
    system = "x86_64-linux";
    modules = [
      microvm.nixosModules.host
      # .microvm for vm-format "host" to nest vms for system development on x86 (Intel)
      # NOTE: Ghaf nested virtualization is not assumed nor tested yet on AMD
      microvm.nixosModules.microvm

      ../configurations/host/configuration.nix
      ../modules/development/authentication.nix
      ../modules/development/ssh.nix
    ];
    format = "vm";
  };

  packages.x86_64-linux.intel-nuc = nixos-generators.nixosGenerate {
    system = "x86_64-linux";
    modules = [
      microvm.nixosModules.host
      ../configurations/host/configuration.nix
      ../modules/development/intel-nuc-getty.nix
      ../modules/development/authentication.nix
      ../modules/development/ssh.nix
    ];
    format = "raw-efi";
  };

  packages.x86_64-linux.default = self.packages.x86_64-linux.vm;

  packages.aarch64-linux.nvidia-jetson-orin = nixos-generators.nixosGenerate (
    import ./nvidia-jetson-orin.nix {inherit jetpack-nixos microvm;}
    // {
      format = "raw-efi";
    }
  );

  packages.aarch64-linux-cross-from-x86_64-linux.nvidia-jetson-orin = nixos-generators.nixosGenerate (
    let
      target = import ./nvidia-jetson-orin.nix {inherit jetpack-nixos microvm;};
    in
      target
      // {
        modules =
          target.modules
          ++ [
            ../modules/cross-compilation/aarch64-linux-from-x86_64-linux.nix
          ];
      }
      // {
        format = "raw-efi";
      }
  );

  # Using Orin as a default aarch64 target for now
  packages.aarch64-linux.default = self.packages.aarch64-linux.nvidia-jetson-orin;
}