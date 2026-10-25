TARGET := iphone:clang:16.5:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CCLinkerPrefs
CCLinkerPrefs_FILES = CCLRootListController.m CCLAppPickerController.m CCLApps.m
CCLinkerPrefs_FRAMEWORKS = UIKit
CCLinkerPrefs_PRIVATE_FRAMEWORKS = Preferences
CCLinkerPrefs_INSTALL_PATH = /Library/PreferenceBundles
CCLinkerPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
