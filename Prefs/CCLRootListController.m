#import "CCLApps.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface CCLRootListController : PSListController
@end

@implementation CCLRootListController {
  NSArray<CCLApp *> *_musicApps;
}

- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
  }
  return _specifiers;
}

// The music app cell shows the chosen app's name through these; the picker
// itself is CCLAppPickerController
- (NSArray<CCLApp *> *)musicApps {
  if (!_musicApps)
    _musicApps = CCLMusicApps();
  return _musicApps;
}

- (NSArray<NSString *> *)musicAppValues {
  return [self.musicApps valueForKey:@"bundleIdentifier"];
}

- (NSArray<NSString *> *)musicAppTitles {
  return [self.musicApps valueForKey:@"name"];
}

@end
