include $(NCS_DIR)/src/ncs/build/include.netsim.mk

## If you need additional init xml files, put them in
## the current directory, and they will be picked up here.

XML = $(wildcard *.xml)
XML += $(NCS_DIR)/netsim/confd/var/confd/cdb/aaa_init.xml

EXTRA_FILES = confd.conf.netsim

YANG = $(wildcard ../src/yang/*.yang)
SUBMODULES          = $(shell grep -l belongs-to ../src/yang/*.yang \
                        | xargs grep -l submodule)
ANNOTATION_MODULES  = $(wildcard ../src/yang/*-ann.yang)
YANG_MODULES = $(filter-out $(SUBMODULES) $(ANNOTATION_MODULES),$(YANG))

BUILTIN_FXS = $(subst $(NCS_DIR)/netsim/confd/etc/confd/,, \
                      $(wildcard $(NCS_DIR)/netsim/confd/etc/confd/*fxs))
BUILTIN_FXS += ietf-netconf.fxs ietf-netconf-with-defaults.fxs

FXS = $(filter-out $(BUILTIN_FXS), \
	$(YANG_MODULES:../src/yang/%.yang=%.fxs))

FLAGS = --yangpath ../src/yang

all: $(FXS)


%.fxs:  ../src/yang/%.yang
	$(CONFDC) $(FLAGS) \
          `ls ../src/yang/$*-ann.yang  > /dev/null 2>&1 && \
              echo "-a ../src/yang/$*-ann.yang"` \
          -c -o $@  $<


# Invoked by netsim, who will sed substitute the %var% PORT variables
# in the confd.conf.netsim file
# The install target here will be invoked multiple times by ncs-netsim,
# once for each device in the simulation network
# The following env variable will be set when ncs-netsim invokes this
# install target
# - DEST_DIR this is where all the files shall go, it's the directory
#   that will be used as execution environment for this ConfD instance
# - NAME this is the name of the managed device
# - COUNTER this is the number of the managed device

install:
	@if [ -z "$${DEST_DIR}" ]; then echo "No DEST_DIR  var"; exit 1; fi
	@if [ ! -d "$${DEST_DIR}" ]; then "echo No DEST_DIR"; exit 1; fi
	mkdir $${DEST_DIR}/cdb 2>/dev/null || true
	mkdir $${DEST_DIR}/logs 2>/dev/null || true
	for i in $(XML); do \
		sed -e 's/%NAME%/$(NAME)/g' -e 's/%COUNTER%/$(COUNTER)/g' -e 's/%TWO_DIGIT_COUNTER%/$(TWO_DIGIT_COUNTER)/g' \
		  $$i > $${DEST_DIR}/cdb/`basename $$i`; \
	done
	for f in $(FXS); do cp $$f $${DEST_DIR}; done
	cp -f $(EXTRA_FILES) $${DEST_DIR}
	cp -af $(NCS_DIR)/netsim/confd/etc/confd/ssh $${DEST_DIR}
clean:
	@rm -f *.fxs
