.PHONY: build setup run clean clean-all help

IMAGE_NAME ?= claude-sandbox
CONFIG_DIR ?= $(HOME)/.claude-sandbox
HOST_CLAUDE ?= $(HOME)/.claude
# Xray release; the SHA below is for the amd64 asset. Override for arm64.
XRAY_VERSION ?= 26.10.21
XRAY_SHA256 ?= 0eec3ed4163c273d8c8bf821f7d219e257921cf584aa3fb970715e458e631978
RUNTIME ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
REPO_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the image with Podman or Docker
	$(RUNTIME) build -t $(IMAGE_NAME) \
		--build-arg XRAY_VERSION=$(XRAY_VERSION) \
		--build-arg XRAY_SHA256=$(XRAY_SHA256) .

setup: ## Copy settings, skills, plugins and git config into the sandbox
	mkdir -p $(CONFIG_DIR)/.claude $(CONFIG_DIR)/.config/gh
	@if [ -f $(HOST_CLAUDE)/settings.json ]; then cp -a $(HOST_CLAUDE)/settings.json $(CONFIG_DIR)/.claude/settings.json; fi
	@if [ ! -f $(CONFIG_DIR)/.claude/.ponytail-active ]; then printf 'full' > $(CONFIG_DIR)/.claude/.ponytail-active; fi
	rm -rf $(CONFIG_DIR)/.claude/skills $(CONFIG_DIR)/.claude/plugins
	@if [ -d $(HOST_CLAUDE)/skills ]; then cp -a $(HOST_CLAUDE)/skills $(CONFIG_DIR)/.claude/skills; fi
	@if [ -d $(HOST_CLAUDE)/plugins ]; then cp -a $(HOST_CLAUDE)/plugins $(CONFIG_DIR)/.claude/plugins; fi
	@for f in installed_plugins.json known_marketplaces.json; do \
		if [ -f $(CONFIG_DIR)/.claude/plugins/$$f ]; then \
			sed -i "s|$(HOME)/.claude|/home/node/.claude|g" $(CONFIG_DIR)/.claude/plugins/$$f; \
		fi; \
	done
	@if [ ! -f $(CONFIG_DIR)/.claude.json ]; then \
		if [ -f $(HOME)/.claude.json ]; then cp $(HOME)/.claude.json $(CONFIG_DIR)/.claude.json; \
		else cp $(REPO_DIR)/.claude.json $(CONFIG_DIR)/.claude.json; fi; \
	fi
	@if [ -f $(HOME)/.gitconfig ]; then cp -a $(HOME)/.gitconfig $(CONFIG_DIR)/.gitconfig; fi
	@if [ -f $(CONFIG_DIR)/.git-credentials ]; then chmod 600 $(CONFIG_DIR)/.git-credentials; fi
	@git config -f $(CONFIG_DIR)/.gitconfig credential.https://codeberg.org.helper store

run: ## Run the container with the current directory mounted
	./scripts/claude-box

clean: ## Remove the image
	$(RUNTIME) rmi $(IMAGE_NAME) || true

clean-all: clean ## Remove the image and all sandbox config
	rm -rf $(CONFIG_DIR)
