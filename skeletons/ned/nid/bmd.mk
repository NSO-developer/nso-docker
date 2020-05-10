SHELL=/bin/bash

# write a build-meta-data.xml for the package, but only if one doesn't already
# exist as we don't want to overwrite one if the package itself generates one.
# Note how this means we have to run this target after the normal package
# compilation.
# The output can be written to a different target directory, which is unusual
# but useful as we can run this target both in the normal Docker build as well
# as from testenv-build - which needs to target different directories.
build-meta-data.xml:
	if [ ! -f $@ ]; then \
		export PKG_NAME=$$(xmlstarlet sel -N x=http://tail-f.com/ns/ncs-packages -t -v '/x:ncs-package/x:name' $$(ls package-meta-data.xml src/package-meta-data.xml.in 2>/dev/null | head -n 1)); \
		export PKG_VERSION=$$(xmlstarlet sel -N x=http://tail-f.com/ns/ncs-packages -t -v '/x:ncs-package/x:package-version' $$(ls package-meta-data.xml src/package-meta-data.xml.in 2>/dev/null | head -n 1)); \
		eval "cat <<< \"$$(</src/nid/build-meta-data.xml)\"" > $(OUTPUT_PATH)$@; fi

.PHONY: build-meta-data.xml
