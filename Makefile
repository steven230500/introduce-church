.PHONY: run test build-mac build-windows dist-mac dist-windows clean reset deps lint check build-all fresh

FLUTTER      := /Users/stevenpatino/development/flutter/bin/flutter
APP_NAME     := Introduce
APP_PATH     := build/macos/Build/Products/Release/$(APP_NAME).app
WIN_APP_PATH := build/windows/x64/runner/Release
DIST_DIR     := dist
VERSION      := $(shell date +%Y%m%d)

run:
	$(FLUTTER) run -d macos

build-mac:
	$(FLUTTER) build macos --release

build-windows:
	$(FLUTTER) build windows --release

build-all: build-mac build-windows

# Build release + package as zip ready to share (no App Store, no signing)
dist-mac: build-mac
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip
	cd build/macos/Build/Products/Release && \
		zip -r --symlinks ../../../../../$(DIST_DIR)/$(APP_NAME)-$(VERSION).zip $(APP_NAME).app
	@echo ""
	@echo "Listo: $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip"
	@echo "Pastor: clic derecho -> Abrir (solo la primera vez, bypass Gatekeeper)"
	open $(DIST_DIR)

# Build release + package as zip for Windows (run this on a Windows machine)
dist-windows: build-windows
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/$(APP_NAME)-windows-$(VERSION).zip
	cd $(WIN_APP_PATH) && \
		zip -r ../../../../$(DIST_DIR)/$(APP_NAME)-windows-$(VERSION).zip .
	@echo ""
	@echo "Listo: $(DIST_DIR)/$(APP_NAME)-windows-$(VERSION).zip"
	@echo "Incluye: .exe + DLLs + data/ — extraer y ejecutar directo"

reset:
	$(FLUTTER) clean
	rm -rf $(DIST_DIR)
	rm -rf ~/Library/Application\ Support/introduce_church
	rm -rf ~/Library/Application\ Support/com.example.introduceChurch
	rm -rf ~/Library/Application\ Support/com.casavida.introduce
	rm -f ~/Library/Preferences/com.example.introduceChurch.plist
	rm -f ~/Library/Preferences/com.casavida.introduce.plist
	defaults delete com.example.introduceChurch 2>/dev/null || true
	defaults delete com.casavida.introduce 2>/dev/null || true

clean:
	$(FLUTTER) clean
	rm -rf $(DIST_DIR)

deps:
	$(FLUTTER) pub get

lint:
	dart analyze lib

test:
	$(FLUTTER) test

# What CI should run: static analysis plus the full test suite.
check: lint test

# Reset todo + build desde cero + abrir dist/
fresh: reset deps dist-mac
