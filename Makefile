###############################################
#
# Makefile
#
###############################################

.DEFAULT_GOAL := build

###############################################

st:
	open -a SourceTree .

open:
	code .

YEAR = 2024
VERSION = 3450200
download:
	curl -o sqlite.zip https://www.sqlite.org/${YEAR}/sqlite-amalgamation-${VERSION}.zip
	-rm -r src
	-mkdir -p src
	cd src; unzip -j ../sqlite.zip

build:
	zig build --verbose

demo:
	./zig-out/bin/sqlite3

macos:
	cd src; zig cc -target aarch64-macos

linux:
	cd sqlite-amalgamation-${VERSION}; zig cc -target x86_64-linux-musl *.c
	# cd sqlite-amalgamation-${VERSION}; zig cc -target x86_64-linux-gnu sqlite.c
