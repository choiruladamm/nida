.DEFAULT_GOAL := help

BUILD_DIR ?= build
CONFIGURATION ?= Debug
DESTINATION ?= platform=macOS,arch=$(shell uname -m)
APP := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/Nida.app
XCODEBUILD := xcodebuild -project Nida.xcodeproj -scheme Nida -configuration "$(CONFIGURATION)" -destination "$(DESTINATION)" -derivedDataPath "$(BUILD_DIR)"

.PHONY: help build test run smoke data-smoke clean project doctor

help: ## Show available commands.
	@awk 'BEGIN {FS = ":.*## "} /^[a-z][a-z-]*:.*## / {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build a locally signed app.
	$(XCODEBUILD) build CODE_SIGN_IDENTITY=-

test: ## Run the focused Swift Testing suite.
	$(XCODEBUILD) test CODE_SIGN_IDENTITY=-

run: build ## Build, force-close running Nida instances, and open the new build.
	@pkill -KILL -x Nida || [ $$? -eq 1 ]
	open -n "$(APP)"

smoke: ## Build Debug and cycle native preview states, then exit.
	$(MAKE) build CONFIGURATION=Debug
	"$(BUILD_DIR)/Build/Products/Debug/Nida.app/Contents/MacOS/Nida" --smoke-test

data-smoke: ## Check live API and offline cache in a temporary directory (uses internet).
	$(MAKE) build CONFIGURATION=Debug
	"$(BUILD_DIR)/Build/Products/Debug/Nida.app/Contents/MacOS/Nida" --data-smoke

clean: ## Clean this project's build products using Xcode.
	$(XCODEBUILD) clean

project: ## Open the project in Xcode.
	open Nida.xcodeproj

doctor: ## Show macOS, Xcode, and Swift versions.
	sw_vers
	xcodebuild -version
	swift --version
