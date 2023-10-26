{
  inputs,
  self,
  pins,
  lib,
  build,
  pkgs,
  pkgsCross,
  pkgsi686Linux,
  callPackage,
  fetchFromGitHub,
  fetchurl,
  moltenvk,
  supportFlags,
  stdenv_32bit,
}: let
  nixpkgs-wine = builtins.path {
    path = inputs.nixpkgs;
    name = "source";
    filter = path: type: let
      wineDir = "${inputs.nixpkgs}/pkgs/applications/emulators/wine/";
    in (
      (type == "directory" && (lib.hasPrefix path wineDir))
      || (type != "directory" && (lib.hasPrefix wineDir path))
    );
  };

  defaults = let
    sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;}).unstable;
  in {
    inherit supportFlags moltenvk;
    patches = [];
    buildScript = "${nixpkgs-wine}/pkgs/applications/emulators/wine/builder-wow.sh";
    configureFlags = ["--disable-tests"];
    geckos = with sources; [gecko32 gecko64];
    mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc13 mingwW64.buildPackages.gcc13];
    monos = with sources; [mono];
    pkgArches = [pkgs pkgsi686Linux];
    platforms = ["x86_64-linux"];
    # stdenv = pkgs.overrideCC stdenv_32bit pkgs.gcc13;
    stdenv = stdenv_32bit;
    wineRelease = "unstable";
  };

  pnameGen = n: n + lib.optionalString (build == "full") "-full";
in {
  wine-ge =
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (defaults
      // {
        pname = pnameGen "wine-ge";
        version = pins.proton-wine.branch;
        src = pins.proton-wine;
      }))
    .overrideAttrs (old: {
      meta = old.meta // {passthru.updateScript = ./update-wine-ge.sh;};
    });

  wine-tkg = callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (lib.recursiveUpdate defaults
    rec {
      pname = pnameGen "wine-tkg";
      version = lib.removeSuffix "\n" (lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION"));
      src = pins.wine-tkg;
    });

  wine-osu = callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (lib.recursiveUpdate defaults
    {
      pname = pnameGen "wine-osu";
      version = "8.16";
      src = fetchFromGitHub {
        owner = "NelloKudo";
        repo = "winello-wine";
        rev = "793c04b2f73898944959c4bccd3597cc23753ae3";
        sha256 = "sha256-aPYFfjVU7Rv9VkAJ+sMr0Zl7BicB9GUotyO/A5ZhsnM=";
      };
      patches = ["${nixpkgs-wine}/pkgs/applications/emulators/wine/cert-path.patch"];
      supportFlags.waylandSupport = true;
    });
}
