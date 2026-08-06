UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
ENVOY_OS := darwin
else
ENVOY_OS := linux
endif

ifeq ($(UNAME_M),arm64)
ENVOY_ARCH := arm64
else ifeq ($(UNAME_M),aarch64)
ENVOY_ARCH := arm64
else
ENVOY_ARCH := amd64
endif

ENVOY_RELEASE_REPO ?= dio/envoy-custom-response-local-reply-body
ENVOY_RELEASE_TAG ?= envoy-custom-response-local-reply-body-v1
ENVOY_ASSET ?= envoy-$(ENVOY_OS)-$(ENVOY_ARCH)-custom-response-local-reply-body
ENVOY_BIN ?= .bin/envoy-custom-response-local-reply-body
BASELINE_ENVOY_IMAGE ?= envoyproxy/envoy:v1.39.0

.PHONY: check-baseline check-patched clean download-envoy observe request-configured-body \
	request-control request-empty-policy request-existing-body run run-baseline

download-envoy:
	mkdir -p .bin
	@if [ ! -x "$(ENVOY_BIN)" ]; then \
		echo "downloading patched Envoy $(ENVOY_ASSET) from $(ENVOY_RELEASE_REPO)/$(ENVOY_RELEASE_TAG)"; \
		curl -fsSL -L \
			"https://github.com/$(ENVOY_RELEASE_REPO)/releases/download/$(ENVOY_RELEASE_TAG)/$(ENVOY_ASSET)" \
			-o "$(ENVOY_BIN)"; \
		chmod +x "$(ENVOY_BIN)"; \
	fi

run: download-envoy
	"$(ENVOY_BIN)" -c config/envoy.yaml

run-baseline:
	docker run --rm --name envoy-local-reply-body-baseline \
		-p 10080:10080 \
		-v "$(CURDIR)/config/envoy.yaml:/etc/envoy/envoy.yaml:ro" \
		"$(BASELINE_ENVOY_IMAGE)" -c /etc/envoy/envoy.yaml

request-control:
	curl -sS http://127.0.0.1:10080/control

request-existing-body:
	curl -sS http://127.0.0.1:10080/existing-body

request-configured-body:
	curl -sS http://127.0.0.1:10080/configured-body

request-empty-policy:
	curl -sS http://127.0.0.1:10080/empty-policy

observe:
	@echo "control:         $$(curl -sS http://127.0.0.1:10080/control)"
	@echo "existing body:  $$(curl -sS http://127.0.0.1:10080/existing-body)"
	@echo "configured body:$$(curl -sS http://127.0.0.1:10080/configured-body)"
	@echo "empty policy:   <$$(curl -sS http://127.0.0.1:10080/empty-policy)>"

check-patched:
	@test "$$(curl -sS http://127.0.0.1:10080/control)" = "control body"
	@test "$$(curl -sS http://127.0.0.1:10080/existing-body)" = "[route body]"
	@test "$$(curl -sS http://127.0.0.1:10080/configured-body)" = "[configured body]"
	@test -z "$$(curl -sS http://127.0.0.1:10080/empty-policy)"
	@echo "custom response local reply body checks passed"

check-baseline:
	@test "$$(curl -sS http://127.0.0.1:10080/control)" = "control body"
	@test "$$(curl -sS http://127.0.0.1:10080/existing-body)" = "[]"
	@test "$$(curl -sS http://127.0.0.1:10080/configured-body)" = "[configured body]"
	@test -z "$$(curl -sS http://127.0.0.1:10080/empty-policy)"
	@echo "current Envoy behavior checks passed"

clean:
	rm -rf .bin
