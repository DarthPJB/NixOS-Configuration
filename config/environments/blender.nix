{ config, pkgs, inputs, ... }:
{
	environment.systemPackages = [
		(pkgs_unstable.blender.override { cudaSupport = true; })
	];
}
