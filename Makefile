define USAGE
Usage:
	make css from=<less source>
	make js from=<es6 source>

The path to less source should be relative to $(SRC_LESS). The path to ES6
source should likewise be relative to $(SRC_ES6).

E.g. to compile the file $(SRC_LESS)/foo.$(BIN).less into css:

    make css from=foo.$(BIN).less

Only source files with a ".$(BIN)" segment right before the extension would
generate compiled artifacts. Internal source files only create dependency files
for use with the source dir watcher.

Speaking of which, you should run watch-src while developing.

endef

SRC_LESS := src/less
SRC_ES6 := src/es6
DIST_CSS := dist/css
DIST_JS := dist/js
TARGET_CSS := target/css
TARGET_JS := target/js
LESSC := node_modules/.bin/lessc
LESSC_MIN := $(LESSC) --clean-css
LESSC_DEPS := $(LESSC) -M
JSC := node_modules/.bin/babel
JS_DEPS := ./es6-deps.js -b $(SRC_ES6) -g $(TARGET_JS)
JS_LINK := node_modules/.bin/browserify
BIN := bundle

dirs = $(shell find $1 -type d)
prefix_replace = $(1:$2%=$3%)

LESS_DIRS := $(call dirs,$(SRC_LESS))
LESS_FILES := $(wildcard $(addsuffix /*.less,$(LESS_DIRS)))
LESS_BIN := $(filter %.$(BIN).less,$(LESS_FILES))
LESS_LIB := $(filter-out %.$(BIN).less,$(LESS_FILES))
CSSD_LIB_FILES := $(call prefix_replace,$(LESS_LIB:.less=.css.d),$(SRC_LESS),$(TARGET_CSS))
CSSD_BIN_FILES := $(call prefix_replace,$(LESS_BIN:.less=.css.d),$(SRC_LESS),$(TARGET_CSS))
CSS_FILES := $(call prefix_replace,$(LESS_FILES:.less=.css),$(SRC_LESS),$(DIST_CSS))
CSS_LIB_FILES := $(call prefix_replace,$(CSS_FILES),$(DIST_CSS),$(TARGET_CSS))
CSS_BIN := $(filter %.$(BIN).css,$(CSS_FILES))
CSS_LIB := $(filter-out %.$(BIN).css,$(CSS_LIB_FILES))

ES6_DIRS := $(call dirs,$(SRC_ES6))
ES6_FILES := $(wildcard $(addsuffix /*.js,$(ES6_DIRS)))
ES6_BIN := $(filter %.$(BIN).js,$(ES6_FILES))
ES6_LIB := $(filter-out %.$(BIN).js,$(ES6_FILES))
JSD_LIB_FILES := $(call prefix_replace,$(addsuffix .d,$(ES6_LIB)),$(SRC_ES6),$(TARGET_JS))
JSD_BIN_FILES := $(call prefix_replace,$(addsuffix .d,$(ES6_BIN)),$(SRC_ES6),$(TARGET_JS))
JS_FILES := $(call prefix_replace,$(ES6_FILES),$(SRC_ES6),$(TARGET_JS))
JS_BIN := $(call prefix_replace,$(ES6_BIN),$(SRC_ES6),$(DIST_JS))
JS_LIB := $(call prefix_replace,$(ES6_LIB),$(SRC_ES6),$(DIST_JS))

ifeq (.bundle,$(suffix $(basename $(from))))
WHICH := DIST
else
WHICH := TARGET
endif

.PHONY: all help clean clean-all css from js css-deps js-deps debug

all: css-deps js-deps
	$(MAKE) $(CSS_BIN) $(JS_BIN)

help:
	$(info $(USAGE))

css: from $($(WHICH)_CSS)/$(basename $(from)).css

js: from $($(WHICH)_JS)/$(basename $(from)).js

from:
ifndef from
	$(info $(USAGE))
	@exit 1
endif

css-deps: $(CSSD_LIB_FILES) $(CSSD_BIN_FILES)

js-deps: $(JSD_LIB_FILES) $(JSD_BIN_FILES)

$(CSSD_LIB_FILES): $(TARGET_CSS)/%.css.d: $(SRC_LESS)/%.less
	# generating dependency list $@
	@mkdir -p $(@D)
	@$(LESSC_DEPS) $< $(TARGET_CSS)/$*.css > $@

$(CSSD_BIN_FILES): $(TARGET_CSS)/%.css.d: $(SRC_LESS)/%.less
	# generating dependency list $@
	@mkdir -p $(@D)
	@$(LESSC_DEPS) $< $(DIST_CSS)/$*.css > $@

$(CSS_BIN): $(DIST_CSS)/%.css: $(TARGET_CSS)/%.css.d
	# compiling $(SRC_LESS)/$*.less -> $@
	@mkdir -p $(@D)
	@$(LESSC) $(SRC_LESS)/$*.less $@

$(CSS_LIB): $(TARGET_CSS)/%.css: $(TARGET_CSS)/%.css.d
	# not compiling non-public (*.$(BIN)) css: $*

%.$(BIN).min.css: %.$(BIN).css
	# minifying $<
	@$(LESSC_MIN) $< $@

$(JSD_LIB_FILES): $(TARGET_JS)/%.d: $(SRC_ES6)/%
	# generating dependency list $@
	@mkdir -p $(@D)
	@$(JS_DEPS) -t $(TARGET_JS)/$* $< > $@

$(JSD_BIN_FILES): $(TARGET_JS)/%.d: $(SRC_ES6)/%
	# generating dependency lists $@
	@mkdir -p $(@D)
	@$(JS_DEPS) -t $(TARGET_JS)/$* -t $(DIST_JS)/$* $< > $@

$(JS_FILES): $(TARGET_JS)/%: $(SRC_ES6)/% $(TARGET_JS)/%.d
	# compiling $@
	@mkdir -p $(@D)
	@$(JSC) $< -o $@

$(JS_BIN): $(DIST_JS)/%: $(TARGET_JS)/%
	# linking $@
	@mkdir -p $(@D)
	@$(JS_LINK) $< -o $@

ifneq ($(wildcard $(TARGET_CSS)),)
-include $(shell find $(TARGET_CSS) -name *.d)
endif

ifneq ($(wildcard $(TARGET_JS)),)
-include $(shell find $(TARGET_JS) -name *.d)
endif

clean:
	-rm -rf $(DIST_CSS) $(DIST_JS)

clean-all: clean
	-rm -rf $(TARGET_CSS) $(TARGET_JS)
