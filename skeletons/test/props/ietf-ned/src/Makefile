all: javac
	$(MAKE) -C ../netsim  all
# Include standard NCS examples build definitions and rules
include $(NCS_DIR)/src/ncs/build/include.ncs.mk

NS  = namespaces

JAVA_PACKAGE = com.example.ietfned
JDIR = $(shell echo $(JAVA_PACKAGE) | sed 's/\./\//g')

JFLAGS = --java-disable-prefix \
         --exclude-enums \
         --java-package $(JAVA_PACKAGE).$(NS) \
         --emit-java java/src/$(JDIR)/$(NS)

javac: fxs
	cd java && ant -q all


SRC = $(wildcard yang/*.yang)
FXS = $(SRC:yang/%.yang=ncsc-out/modules/fxs/%.fxs)
DIRS =  ncsc-out ../load-dir
DIRS += ../shared-jar ../private-jar java/src/$(JDIR)/$(NS)
DIRS += ../python/ietf_ned
NED_ID_ARG = $(shell [ -x ${NCS_DIR}/support/ned-ncs-ned-id-arg ] && \
               ${NCS_DIR}/support/ned-ncs-ned-id-arg package-meta-data.xml.in)

## Uncomment and patch the line below if you have a dependency to
## other YANG files
# YANGPATH += ../../<pkg-name>/src/yang

NCSCPATH   = $(YANGPATH:%=--yangpath %)

fxs: $(DIRS) ../package-meta-data.xml ncsc-out/.done
.PHONY: fxs

$(DIRS):
	mkdir -p $@

../package-meta-data.xml: package-meta-data.xml.in
	rm -rf $@
	if [ -x ${NCS_DIR}/support/ned-make-package-meta-data ]; then \
	    ${NCS_DIR}/support/ned-make-package-meta-data $<;         \
	else                                                          \
	    grep -v 'to be replaced by build' $< > $@;                \
	fi
	chmod -w $@

ncsc-out/.done:	$(SRC)
	$(NCSC) --ncs-compile-bundle yang                   \
	    --ncs-device-dir ncsc-out                        \
	                            \
	                                \
	    --ncs-device-type netconf                        \
	    $(NCSCPATH)                                     \
	    $(NED_ID_ARG)                                   \
	    $(NCSC_EXTRA_FLAGS)
	cp ncsc-out/modules/fxs/*.fxs ../load-dir
	for f in `echo ../load-dir/*.fxs`; do \
	    n=`basename $$f | sed 's/\.fxs//'`; \
	    $(NCSC) $(JFLAGS)/$${n}.java $$f  || exit 1; \
	    $(NCSC)                                 \
	        --emit-python ../python/ietf_ned $$f  || \
	    exit 1;                                                      \
	   true; \
	done
	touch ncsc-out/.done

clean:
	rm -rf $(DIRS)
	rm -rf ../package-meta-data.xml
	$(MAKE) -C ../netsim clean
	cd java && ant -q clean || true
.PHONY: clean
