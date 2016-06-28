SRC_LESS := src/less
SRC_ES6 := src/es6
DIST_CSS := dist/css
DIST_JS := dist/js
TARGET_CSS := target/css
TARGET_JS := target/js
CSSC := node_modules/.bin/lessc
CSSMIN := $(CSSC) --clean-css
CSSDEPS := $(CSSC) -M
JSC := node_modules/.bin/babel
JSDEPS := node es6-deps.js
JSLINK := node_modules/.bin/browserify
BIN := bundle

files = $(shell find $1 -name '$2' -printf '%P\n')

.PHONY: init clean nuke

init:
	@# just triggering .d targets

LESS_STEM := $(call files,$(SRC_LESS),*.less)
LESS_BIN := $(filter %.$(BIN).less,$(LESS_STEM))
CSSD_BIN := $(addprefix $(TARGET_CSS)/,$(LESS_BIN:.less=.d))
CSS_BIN := $(addprefix $(DIST_CSS)/,$(LESS_BIN:.less=.css))
CSSMIN_BIN := $(CSS_BIN:.css=.min.css)

$(CSSD_BIN): $(TARGET_CSS)/%.d: $(SRC_LESS)/%.less
	# generating dependency list $@
	@mkdir -p $(@D)
	@$(CSSDEPS) $< "$@ $(DIST_CSS)/$*.css" \
		| sed 's|:[[:space:]]*|: $(abspath $<) |' \
		> $@

$(CSS_BIN): $(DIST_CSS)/%.css: $(TARGET_CSS)/%.d
	# compiling $*.less -> $@
	@mkdir -p $(@D)
	@$(CSSC) $(SRC_LESS)/$*.less $@

$(CSSMIN_BIN): $(DIST_CSS)/%.min.css: $(DIST_CSS)/%.css
	# minifying $<
	@$(CSSMIN) $< $@

-include $(CSSD_BIN)


ES6_STEM := $(call files,$(SRC_ES6),*.js)
ES6_BIN := $(filter %.$(BIN).js,$(ES6_STEM))
JSD_BIN := $(addprefix $(TARGET_JS)/,$(ES6_BIN:.js=.d))
JS_BIN := $(addprefix $(DIST_JS)/,$(ES6_BIN))
JS_O := $(addprefix $(TARGET_JS)/,$(ES6_STEM))

$(JS_BIN): $(DIST_JS)/%.js: $(TARGET_JS)/%.js $(TARGET_JS)/%.d
	@mkdir -p $(@D)
	# linking $@
	@$(JSLINK) $< -o $@

$(JSD_BIN): $(TARGET_JS)/%.d: $(SRC_ES6)/%.js
	@mkdir -p $(@D)
	# generating dependency list $@
	@$(JSDEPS) -t $@  $< \
		| tee $@ \
		| sed -re 's|[^:]+:|$(DIST_JS)/$*.js:|' \
		-e 's|[[:space:]]$(SRC_ES6)| $(TARGET_JS)|g' \
		>> $@

$(JS_O): $(TARGET_JS)/%.js: $(SRC_ES6)/%.js
	@mkdir -p $(@D)
	# compiling $* -> $@
	@$(JSC) $< -o $@

-include $(JSD_BIN)


clean:
	-rm -f $(CSS_BIN) $(JS_BIN) $(CSSMIN_BIN)

nuke:
	-rm -rf $(TARGET_CSS) $(TARGET_JS) $(DIST_CSS) $(DIST_JS)

print-%: ; @echo $*=$($*)
