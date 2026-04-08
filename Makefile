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

home:
	open https://www.sqlite.org

YEAR = 2026
VERSION = 3510200
download:
	curl -o sqlite.zip https://www.sqlite.org/${YEAR}/sqlite-amalgamation-${VERSION}.zip
	-mkdir -p src
	cd src; unzip -j ../sqlite.zip

build:
	zig build

dist:
	zig build -Doptimize=ReleaseSafe

format:
	zig fmt **/*.zig

demo:
	./zig-out/bin/sqlite3

clean:
	-rm -r zig-out

all: download build
	echo "done"
