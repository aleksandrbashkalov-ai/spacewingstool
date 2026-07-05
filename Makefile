APP_NAME = Spacewingstool
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONFIG = debug

.PHONY: all build app run release install clean

all: build

build:
	swift build -c $(CONFIG)

app: build
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(CONFIG)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	cp "Sources/$(APP_NAME)/Info.plist" "$(APP_BUNDLE)/Contents/"
	cp "Sources/$(APP_NAME)/Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/"
	@echo "✅ Created $(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

release:
	$(MAKE) CONFIG=release app

install: release
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "✅ Installed to /Applications/$(APP_NAME).app"

# ── Developer ID Signing & Notarization ──
# Requirements:
#   - Apple Developer Program account
#   - Developer ID Application certificate in keychain
#   - App-specific password for notarization (or use --apiKey / --apiIssuer)
# Usage:
#   make release-sign    # Build + sign + notarize + staple
#   make sign            # Sign only (pre-built bundle)
#   make notarize        # Notarize only (signed bundle)

DEV_ID ?= "Developer ID Application: Your Name (TEAMID)"
NOTARY_APPLE_ID ?= your@apple.id
NOTARY_PASSWORD ?= @keychain:AC_PASSWORD
NOTARY_TEAM_ID ?= TEAMID

.PHONY: sign notarize staple release-sign

sign: app
	codesign --deep --force --options=runtime \
		--sign "$(DEV_ID)" \
		"$(APP_BUNDLE)"
	@echo "✅ Signed with hardened runtime"

notarize: sign
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(APP_BUNDLE).zip"
	xcrun notarytool submit "$(APP_BUNDLE).zip" \
		--apple-id "$(NOTARY_APPLE_ID)" \
		--password "$(NOTARY_PASSWORD)" \
		--team-id "$(NOTARY_TEAM_ID)" \
		--wait
	@echo "✅ Notarized"
	rm -f "$(APP_BUNDLE).zip"

staple: sign
	xcrun stapler staple "$(APP_BUNDLE)"
	@echo "✅ Staple ticket applied"

release-sign:
	$(MAKE) CONFIG=release sign
	$(MAKE) CONFIG=release notarize
	$(MAKE) CONFIG=release staple

clean:
	swift clean
	rm -rf "$(APP_BUNDLE)"
