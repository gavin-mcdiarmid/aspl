main:
	zig build --prominent-compile-errors;
	touch aspl
	rm aspl
	ln -s ./zig-out/bin/aspl ./aspl
watch:
	zig build -p stage4 --watch -fincremental --prominent-compile-errors
