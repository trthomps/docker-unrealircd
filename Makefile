VERSION ?= $(shell grep -E 'ENV VERSION' Dockerfile | cut -d'=' -f 2)

.PHONY: build
build:
	docker build -t unrealircd:$(VERSION) .