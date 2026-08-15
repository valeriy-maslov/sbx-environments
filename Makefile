IMAGE   ?= vgm-sandbox
TAG     ?= v1
CONTEXT ?= templates/vgm-sandbox
TARBALL ?= dist/$(IMAGE)-$(TAG).tar

.PHONY: vgm-sandbox

vgm-sandbox: vgm-sandbox-build vgm-sandbox-save

vgm-sandbox-build:
	docker build --provenance=false --sbom=false -t $(IMAGE):$(TAG) $(CONTEXT)

vgm-sandbox-save:
	mkdir -p $(dir $(TARBALL))
	docker image save $(IMAGE):$(TAG) -o $(TARBALL)
