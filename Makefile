.DEFAULT_GOAL := help

BUILD_DIR ?= build
CONFIGURATION ?= Debug
DESTINATION ?= platform=macOS,arch=$(shell uname -m)
ifeq ($(CONFIGURATION),Debug)
PRODUCT := Nida Dev
else ifeq ($(CONFIGURATION),Release)
PRODUCT := Nida
else
$(error Unsupported CONFIGURATION: $(CONFIGURATION))
endif
APP := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(PRODUCT).app
DEV_REMINDERS ?= 0
RUN_ARGS := $(if $(filter 1,$(DEV_REMINDERS)),--enable-development-reminders,)
SOURCE_SHA ?=
XCODEBUILD := xcodebuild -project Nida.xcodeproj -scheme Nida -configuration "$(CONFIGURATION)" -destination "$(DESTINATION)" -derivedDataPath "$(BUILD_DIR)" $(if $(SOURCE_SHA),NIDA_SOURCE_COMMIT=$(SOURCE_SHA),)

.PHONY: help build test run smoke data-smoke clean project doctor dmg promote rollback release-test icons

help: ## Show available commands.
	@awk 'BEGIN {FS = ":.*## "} /^[a-z][a-z-]*:.*## / {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build a locally signed app.
	$(XCODEBUILD) build CODE_SIGN_IDENTITY=-

test: ## Run the focused Swift Testing suite.
	$(XCODEBUILD) test CODE_SIGN_IDENTITY=-

run: build ## Build and restart only the selected variant (Debug: Nida Dev).
	@pkill -KILL -x "$(PRODUCT)" || [ $$? -eq 1 ]
	open -n "$(APP)" --args $(RUN_ARGS)

smoke: ## Restart only Nida Dev, build Debug, cycle previews, then exit.
	@pkill -KILL -x "Nida Dev" || [ $$? -eq 1 ]
	$(MAKE) build CONFIGURATION=Debug
	"$(BUILD_DIR)/Build/Products/Debug/Nida Dev.app/Contents/MacOS/Nida Dev" --smoke-test

data-smoke: ## Check live API and offline cache in a temporary directory (uses internet).
	$(MAKE) build CONFIGURATION=Debug
	"$(BUILD_DIR)/Build/Products/Debug/Nida Dev.app/Contents/MacOS/Nida Dev" --data-smoke

clean: ## Clean this project's build products using Xcode.
	$(XCODEBUILD) clean

project: ## Open the project in Xcode.
	open Nida.xcodeproj

doctor: ## Show macOS, Xcode, and Swift versions.
	sw_vers
	xcodebuild -version
	swift --version

icons: ## Regenerate native Stable/Dev app icon assets.
	swift scripts/generate-icons.swift

release-test: ## Test packaging/promotion failure paths without touching installed apps.
	python3 -m unittest discover -s scripts -p 'test_*.py' -v

dmg: ## Test/build this committed source and create a verified personal DMG.
	python3 scripts/release.py dmg

promote: ## Install exact CI-passed origin/main as Stable; keep one previous app.
	python3 scripts/release.py promote

rollback: ## Restore the previous Stable binary; preserve settings and Dev.
	python3 scripts/release.py rollback
