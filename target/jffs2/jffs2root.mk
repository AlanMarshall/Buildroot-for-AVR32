#############################################################
#
# Build the jffs2 root filesystem image
#
#############################################################

ifneq ($(strip $(BR2_TARGET_ROOTFS_JFFS2_READ_PARTITION_SETUP)),y)
JFFS2_OPTS := --eraseblock=$(strip $(BR2_TARGET_ROOTFS_JFFS2_EBSIZE))
SUMTOOL_OPTS := $(JFFS2_OPTS)

ifeq ($(strip $(BR2_TARGET_ROOTFS_JFFS2_PAD)),y)
ifneq ($(strip $(BR2_TARGET_ROOTFS_JFFS2_PADSIZE)),0x0)
JFFS2_OPTS += --pad=$(strip $(BR2_TARGET_ROOTFS_JFFS2_PADSIZE))
else
JFFS2_OPTS += --pad
endif
SUMTOOL_OPTS += -p
endif

ifeq ($(BR2_TARGET_ROOTFS_JFFS2_SQUASH),y)
JFFS2_OPTS += --squash
endif

ifeq ($(BR2_TARGET_ROOTFS_JFFS2_LE),y)
JFFS2_OPTS += --little-endian
SUMTOOL_OPTS += --little-endian
endif

ifeq ($(BR2_TARGET_ROOTFS_JFFS2_BE),y)
JFFS2_OPTS += --big-endian
SUMTOOL_OPTS += --big-endian
endif

JFFS2_OPTS += -s $(BR2_TARGET_ROOTFS_JFFS2_PAGESIZE)
ifeq ($(BR2_TARGET_ROOTFS_JFFS2_NOCLEANMARKER),y)
JFFS2_OPTS += --no-cleanmarkers
SUMTOOL_OPTS += --no-cleanmarkers
endif

JFFS2_TARGET := $(strip $(subst ",,$(BR2_TARGET_ROOTFS_JFFS2_OUTPUT)))
#"))
ifneq ($(TARGET_DEVICE_TABLE),)
JFFS2_OPTS += -D $(TARGET_DEVICE_TABLE)
endif

else # BR2_TARGET_ROOTFS_JFFS2_READ_PARTITION_SETUP

ifeq ($(BR2_TARGET_ROOTFS_JFFS2_BE),y)
JFFS2_OPTS := --big-endian
else
JFFS2_OPTS := --little-endian
endif

ifeq ($(BR2_TARGET_ROOTFS_JFFS2_SQUASH),y)
JFFS2_OPTS += --squash
endif

JFFS2_TARGET_MULTI := $(strip $(subst ",,$(BR2_TARGET_ROOTFS_JFFS2_OUTPUT)))
#"))
JFFS2_DEVFILE = $(strip $(subst ",,$(BR2_TARGET_ROOTFS_JFFS2_DEVFILE)))
#"))

endif

#
# mtd-host is a dependency which builds a local copy of mkfs.jffs2 if it is needed.
# the actual build is done from package/mtd/mtd.mk and it sets the
# value of MKFS_JFFS2 to either the previously installed copy or the one
# just built.
#
$(JFFS2_TARGET): host-fakeroot makedevs mtd-host
	-@find $(TARGET_DIR) -type f -perm +111 | xargs $(STRIPCMD) 2>/dev/null || true
ifneq ($(BR2_HAVE_MANPAGES),y)
	@rm -rf $(TARGET_DIR)/usr/man
	@rm -rf $(TARGET_DIR)/usr/share/man
endif
ifneq ($(BR2_HAVE_INFOPAGES),y)
	@rm -rf $(TARGET_DIR)/usr/info
endif
	@rmdir -p --ignore-fail-on-non-empty $(TARGET_DIR)/usr/share
	$(if $(TARGET_LDCONFIG),test -x $(TARGET_LDCONFIG) && $(TARGET_LDCONFIG) -r $(TARGET_DIR) 2>/dev/null)
	# Use fakeroot to pretend all target binaries are owned by root
	rm -f $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
	touch $(PROJECT_BUILD_DIR)/.fakeroot.00000
	cat $(PROJECT_BUILD_DIR)/.fakeroot* > $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
	echo "chown -R 0:0 $(TARGET_DIR)" >> $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
ifneq ($(TARGET_DEVICE_TABLE),)
	# Use fakeroot to pretend to create all needed device nodes
	echo "$(STAGING_DIR)/bin/makedevs -d $(TARGET_DEVICE_TABLE) $(TARGET_DIR)" \
		>> $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
endif
	# Use fakeroot so mkfs.jffs2 believes the previous fakery
ifneq ($(BR2_TARGET_ROOTFS_JFFS2_SUMMARY),)
	echo "$(MKFS_JFFS2) $(JFFS2_OPTS) -d $(TARGET_DIR) -o $(JFFS2_TARGET).nosummary && " \
		"$(SUMTOOL) $(SUMTOOL_OPTS) -i $(JFFS2_TARGET).nosummary -o $(JFFS2_TARGET) && " \
		"rm $(JFFS2_TARGET).nosummary" \
		>> $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
else
	echo "$(MKFS_JFFS2) $(JFFS2_OPTS) -d $(TARGET_DIR) -o $(JFFS2_TARGET)" \
		>> $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
endif
	chmod a+x $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
	$(STAGING_DIR)/usr/bin/fakeroot -- $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
	-@rm -f $(PROJECT_BUILD_DIR)/_fakeroot.$(notdir $(JFFS2_TARGET))
	@ls -l $(JFFS2_TARGET)
ifeq ($(BR2_JFFS2_TARGET_SREC),y)
	$(TARGET_CROSS)objcopy -I binary -O srec --adjust-vma 0xa1000000 $(JFFS2_TARGET) $(JFFS2_TARGET).srec
	@ls -l $(JFFS2_TARGET).srec
endif

# Build the JFFS2 partitions
$(JFFS2_TARGET_MULTI):
	@if [ ! -f $(BR2_TARGET_ROOTFS_JFFS2_READ_PARTITION_SETUP_FILE) ]; then		 \
		echo;									 \
		echo "Please specify BR2_TARGET_ROOTFS_JFFS2_READ_PARTITION_SETUP_FILE"; \
		echo "in menuconfig, or else JFFS2 partitions can not be used.";	 \
		echo;									 \
		exit 1;									 \
	fi;
	target/jffs2/make-part-images.sh $(JFFS2_TARGET_MULTI) \
		$(TARGET_DIR) $(STAGING_DIR) \
		$(BR2_TARGET_ROOTFS_JFFS2_READ_PARTITION_SETUP_FILE) \
		$(TARGET_DEVICE_TABLE) $(JFFS2_OPTS)
ifeq ($(BR2_JFFS2_TARGET_SREC),y)
	@for image in $@-*; do \
		$(TARGET_CROSS)objcopy -I binary -O srec --adjust-vma 0xa1000000 $$image $$image.srec; \
		ls -l $$image.srec; \
	done;
endif

JFFS2_COPYTO := $(strip $(subst ",,$(BR2_TARGET_ROOTFS_JFFS2_COPYTO)))
#"))

jffs2root: host-fakeroot makedevs mtd-host $(JFFS2_TARGET) $(JFFS2_TARGET_MULTI)
ifneq ($(JFFS2_COPYTO),)
ifneq ($(JFFS2_TARGET),)
	@cp -f $(JFFS2_TARGET) $(JFFS2_COPYTO)
else
	@cp -f $(JFFS2_TARGET_MULTI)-* $(JFFS2_COPYTO)
endif
endif

jffs2root-source: mtd-host-source

jffs2root-clean: mtd-host-clean
ifneq ($(JFFS2_TARGET),)
	-rm -f $(JFFS2_TARGET)
else
	-rm -f $(JFFS2_TARGET_MULTI)-*
endif

jffs2root-dirclean: mtd-host-dirclean
ifneq ($(JFFS2_TARGET),)
	-rm -f $(JFFS2_TARGET)
else
	-rm -f $(JFFS2_TARGET_MULTI)-*
endif

#############################################################
#
# Toplevel Makefile options
#
#############################################################
ifeq ($(strip $(BR2_TARGET_ROOTFS_JFFS2)),y)
TARGETS+=jffs2root
endif
