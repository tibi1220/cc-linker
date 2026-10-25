TARGET := iphone:clang:16.5:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCLinker
CCLinker_FILES = Tweak.x
CCLinker_CFLAGS = -fobjc-arc
CCLinker_PRIVATE_FRAMEWORKS = FrontBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
