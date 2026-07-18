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
	zig build --release=safe

format:
	zig fmt **/*.zig

test:
	zig build test

validate: clean format build test
	echo "validate done"

demo:
	./zig-out/bin/sqlite3

clean:
	-rm -r zig-out

all: download build
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

# Add the shared styleguide submodule.
substyle:
	git submodule add git@github.com:inferise/styleguide.git styleguide

# Add the wiki submodule.
subwiki:
	git submodule add git@github.com:inferise/zigsqlite.wiki.git wiki

# Init/update all submodules.
subpull:
	git submodule update --init --recursive
