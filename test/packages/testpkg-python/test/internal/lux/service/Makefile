#
# The 'lux' test tool can be obtained from:
#
#   https://github.com/hawk/lux.git
#

# Make sure the TARGET_DIR has got the following make targets:
.PHONY: clean build start stop

export TARGET_DIR=../../../../../..

.PHONY: test
test:
	lux run.lux

clean:
	$(MAKE) -C $(TARGET_DIR) clean

build:
	$(MAKE) -C $(TARGET_DIR) build

start:
	$(MAKE) -C $(TARGET_DIR) start

stop:
	$(MAKE) -C $(TARGET_DIR) stop
