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
      ../configurations/host/configuration.nix
      ../modules/development/authentication.nix
      ../modules/development/ssh.nix
      ../modules/development/nix.nix

      ../modules/hardware/intel.nix
      ../configurations/host/microvm.nix
      (import ../configurations/host/netvm.nix {
        inherit self;
        system = "x86_64-linux";
      })
    ];
    format = "vm";
  };

  packages.x86_64-linux.intel-nuc = nixos-generators.nixosGenerate {
    system = "x86_64-linux";
    modules = [
      microvm.nixosModules.host
      ../configurations/host/configuration.nix
      ../modules/development/intel-nuc-getty.nix
      ../modules/development/nix.nix
      ../modules/development/authentication.nix
      ../modules/development/ssh.nix
      ../modules/development/nix.nix

      ../modules/hardware/intel.nix
      ../configurations/host/microvm.nix
      (import ../configurations/host/netvm.nix {
        inherit self;
        system = "x86_64-linux";
      })
    ];
    format = "raw-efi";
  };

  packages.x86_64-linux.default = self.packages.x86_64-linux.vm;

  packages.aarch64-linux.nvidia-jetson-orin = nixos-generators.nixosGenerate (
    import ./nvidia-jetson-orin.nix {inherit self jetpack-nixos microvm;}
    // {
      format = "raw-efi";
    }
  );

  # Using Orin as a default aarch64 target for now
  packages.aarch64-linux.default = self.packages.aarch64-linux.nvidia-jetson-orin;
}
