#import <Foundation/Foundation.h>

// Stored instead of a bundle ID to follow whichever app is playing
extern NSString *const CCLNowPlayingValue;

@interface CCLApp : NSObject
@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *name;
@end

// Choices for the music app: the now playing entry first, then every visible
// user app plus Apple's audio apps, sorted by name
NSArray<CCLApp *> *CCLMusicApps(void);
