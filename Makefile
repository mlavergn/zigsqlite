###############################################
#
# Makefile
#
###############################################

# Optional include to extend the makefile targets
-include ../styleguide/Makefile.in

.DEFAULT_GOAL := build

###############################################

st:
	open -a SourceTree .

open:
	code .

home:
	open https://www.sqlite.org

build:
	zig build

dist:
	zig build --release=safe

test:
	zig build test

demo:
	./zig-out/bin/sqlite3

# Build, then open the sqlite3 shell. Phony: cli/ is also a directory.
.PHONY: cli
cli: build
	./zig-out/bin/sqlite3

clean:
	-rm -r zig-out

all: build
	echo "done"

# ---------------------------------------------
# Release
# ---------------------------------------------

# Derive the version from the .version field in build.zig.zon (e.g. 0.2.2).
TAG_VERSION := $(shell sed -n -E 's/^[[:space:]]*\.version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' build.zig.zon)

# Create an annotated git tag matching the build.zig.zon version (e.g. 0.2.2), then push it.
tag:
	@test -n "$(TAG_VERSION)" || { echo "❌ could not read .version from build.zig.zon"; exit 1; }
	git tag -a "$(TAG_VERSION)" -m "$(TAG_VERSION)"
	git push
	git push --tags

# ---------------------------------------------
# Submodules
# ---------------------------------------------

# Add the wiki submodule.
subwiki:
	git submodule add git@github.com:mlavergn/zigsqlite.wiki.git wiki

# Init/update all submodules.
subpull:
	git submodule update --init --recursive
