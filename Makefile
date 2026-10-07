SHELL := /bin/bash
DERIVED := build/DerivedData
XCB := xcodebuild -project Lirnyk.xcodeproj -scheme Lirnyk -derivedDataPath $(DERIVED) -destination "platform=macOS,arch=arm64"
RELEASE_APP := $(DERIVED)/Build/Products/Release/Lirnyk.app

.PHONY: project build test test-release install release dmg clean

project:
	xcodegen generate --quiet

build: project
	$(XCB) -configuration Debug build -quiet

test: project
	set -o pipefail; $(XCB) test 2>&1 | grep -E "(✔|✘|Test run|error:|\*\* TEST)"

test-release:
	scripts/release-tests.sh

install: project
	$(XCB) -configuration Release build -quiet
	-pkill -x Lirnyk
	rm -rf /Applications/Lirnyk.app
	ditto $(RELEASE_APP) /Applications/Lirnyk.app
	open /Applications/Lirnyk.app

release: test-release
	scripts/release.sh

dmg:
	scripts/dmg.sh

clean:
	rm -rf build Lirnyk.xcodeproj
