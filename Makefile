UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

CC = clang
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

TOOLS := arm-echo arm-cat arm-upper arm-lines
SRC_DIR := src
BUILD_DIR := build
BIN_DIR := bin

OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(TOOLS)))
BINARIES := $(addprefix $(BIN_DIR)/,$(TOOLS))

ASFLAGS := -arch arm64 -I$(SRC_DIR)
LDFLAGS := -arch arm64

.PHONY: all check-platform test clean install uninstall

all: check-platform $(BINARIES)

check-platform:
	@if [ "$(UNAME_S)" != "Darwin" ] || [ "$(UNAME_M)" != "arm64" ]; then \
		echo "This ARM tool set currently targets Darwin arm64; found $(UNAME_S) $(UNAME_M)." >&2; \
		exit 1; \
	fi

$(BUILD_DIR) $(BIN_DIR):
	mkdir -p $@

$(BUILD_DIR)/arm-echo.o: $(SRC_DIR)/arm_echo.S $(SRC_DIR)/common.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/arm-cat.o: $(SRC_DIR)/arm_cat.S $(SRC_DIR)/common.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/arm-upper.o: $(SRC_DIR)/arm_upper.S $(SRC_DIR)/common.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/arm-lines.o: $(SRC_DIR)/arm_lines.S $(SRC_DIR)/common.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BIN_DIR)/%: $(BUILD_DIR)/%.o | $(BIN_DIR)
	$(CC) $(LDFLAGS) $< -o $@

test: all
	./scripts/test.sh

install: all
	mkdir -p $(BINDIR)
	cp $(BINARIES) $(BINDIR)/

uninstall:
	rm -f $(addprefix $(BINDIR)/,$(TOOLS))

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)
