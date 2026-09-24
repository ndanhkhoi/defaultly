# Command Line Tools need the macOS 26 SDK for SwiftUI (see scripts/sdk-root.sh), a linker flag so the app records
# that SDK's version (see scripts/swift-flags.sh), and with a custom SDK, SwiftPM no longer finds the Swift Testing
# macro plugin on its own.
SDK := $(shell scripts/sdk-root.sh)
SWIFT_FLAGS := $(shell scripts/swift-flags.sh)
ifneq ($(SDK),)
export SDKROOT := $(SDK)
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing
endif

.PHONY: build test integration-test smoke-test lint app universal package run icon clean

build:
	swift build $(SWIFT_FLAGS)

test:
	swift test $(SWIFT_FLAGS) $(TEST_FLAGS)

integration-test:
	DEFAULTLY_INTEGRATION=1 swift test $(SWIFT_FLAGS) $(TEST_FLAGS) --filter 'LaunchServicesIntegrationTests|UpdateIntegrationTests'

smoke-test:
	scripts/smoke-test.sh

lint:
	plutil -lint Resources/Info.plist Resources/*.lproj/*

app:
	scripts/build-app.sh

universal:
	ARCHS="arm64 x86_64" scripts/build-app.sh

package: universal
	scripts/package-release.sh

run: app
	open dist/Defaultly.app

icon:
	swift scripts/generate-icon.swift Resources/AppIcon.icns

clean:
	rm -rf .build dist
