{ pkgs }: {
	deps = [
   pkgs.openssl
		pkgs.rakudo
		pkgs.moarvm
		pkgs.nqp
		pkgs.zef
	];
}