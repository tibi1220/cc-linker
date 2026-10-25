#import "CCLApps.h"

NSString *const CCLNowPlayingValue = @"nowplaying";

@interface LSApplicationProxy : NSObject
@property(nonatomic, readonly) NSString *applicationIdentifier;
@property(nonatomic, readonly) NSString *localizedName;
@property(nonatomic, readonly) NSString *applicationType;
@property(nonatomic, readonly) NSArray<NSString *> *appTags;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end

@implementation CCLApp
@end

NSArray<CCLApp *> *CCLMusicApps(void) {
  NSSet<NSString *> *appleAudioApps = [NSSet setWithArray:@[
    @"com.apple.Music", @"com.apple.podcasts", @"com.apple.iBooks"
  ]];
  NSMutableArray<CCLApp *> *apps = [NSMutableArray array];
  for (LSApplicationProxy *proxy in
       [[NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace]
           allInstalledApplications]) {
    BOOL user = [proxy.applicationType isEqualToString:@"User"];
    BOOL hidden = [proxy.appTags containsObject:@"hidden"];
    if (!proxy.applicationIdentifier || hidden ||
        !(user || [appleAudioApps containsObject:proxy.applicationIdentifier]))
      continue;

    CCLApp *app = [CCLApp new];
    app.bundleIdentifier = proxy.applicationIdentifier;
    app.name = proxy.localizedName ?: proxy.applicationIdentifier;
    [apps addObject:app];
  }
  [apps sortUsingComparator:^NSComparisonResult(CCLApp *a, CCLApp *b) {
    return [a.name localizedCaseInsensitiveCompare:b.name];
  }];

  CCLApp *nowPlaying = [CCLApp new];
  nowPlaying.bundleIdentifier = CCLNowPlayingValue;
  nowPlaying.name = @"Now Playing App";
  [apps insertObject:nowPlaying atIndex:0];
  return apps;
}
