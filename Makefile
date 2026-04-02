CLI_VERSION := 1.0.0
BIN_NAME    := cappt
CLI_DIR     := tools/cappt
DIST_DIR    := dist

TARGETS := darwin-amd64 darwin-arm64 linux-amd64 linux-arm64 windows-amd64

.PHONY: build build-all package checksums clean $(TARGETS)

build:
	mkdir -p $(DIST_DIR)
	cd $(CLI_DIR) && go build -ldflags="-X main.version=$(CLI_VERSION)" -o ../../$(DIST_DIR)/$(BIN_NAME) .

build-all: $(TARGETS)

$(TARGETS):
	$(eval OS   := $(word 1,$(subst -, ,$@)))
	$(eval ARCH := $(word 2,$(subst -, ,$@)))
	$(eval EXT  := $(if $(filter windows,$(OS)),.exe,))
	mkdir -p $(DIST_DIR)
	cd $(CLI_DIR) && GOOS=$(OS) GOARCH=$(ARCH) go build \
		-ldflags="-X main.version=$(CLI_VERSION)" \
		-o ../../$(DIST_DIR)/$(BIN_NAME)-$@$(EXT) .

package:
	mkdir -p $(DIST_DIR)
	cd skills && zip -r ../$(DIST_DIR)/cappt-skill.zip cappt/

checksums:
	cd $(DIST_DIR) && shasum -a 256 $(BIN_NAME)-* > checksums.txt
	cat $(DIST_DIR)/checksums.txt

clean:
	rm -f $(CLI_DIR)/$(BIN_NAME)
	rm -rf $(DIST_DIR)
