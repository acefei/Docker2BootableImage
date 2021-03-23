.PHONY: help
.DEFAULT_GOAL := help

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

ROOT_PATH := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
DOCKER_BUILD=DOCKER_BUILDKIT=1 docker build $(BUILD_ARGS) -t $@ --target $@ .
DIND_ARGS=-v /var/run/docker.sock:/var/run/docker.sock -v $(shell which docker):/bin/docker
FOR_LOOP_ARGS=--privileged -v /dev:/dev
DOCKER_RUN=docker run -it $(FOR_LOOP_ARGS) $(DIND_ARGS) -v $(PWD):/app -w /app $<

base:
	$(DOCKER_BUILD)

dev-env: base ## enter container to debug code
	$(DOCKER_RUN) 

image: base ## generate bootable image
	$(DOCKER_RUN) bash $(SH_TRACE) src/image_builder.sh

bootup: src/linux.img ## boot up the bootable image
	sudo qemu-system-x86_64 -hda $< -curses
