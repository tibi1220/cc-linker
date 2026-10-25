// CCLinker: swipe a Control Center module (or a single connectivity button)
// to jump to its page in Settings, or to the chosen music app.

#import <FrontBoardServices/FBSSystemService.h>
#import <SpringBoard/SBControlCenterController.h>
#import <SpringBoard/SBMediaController.h>
#import <UIKit/UIKit.h>

#define kPrefsDomain @"com.tibi1220.cclinker"
#define kPrefsChangedNotification "com.tibi1220.cclinker/ReloadPrefs"

@interface CCUIContentModuleContainerViewController : UIViewController
@property(nonatomic, copy, readonly) NSString *moduleIdentifier;
- (BOOL)isExpanded;
@end

@interface SBApplication : NSObject
@property(nonatomic, readonly) NSString *bundleIdentifier;
@end

typedef NS_ENUM(NSInteger, CCLGesture) {
  CCLGestureSwipeRight,
  CCLGestureSwipeLeft,
  CCLGestureSwipeUp,
  CCLGestureSwipeDown,
};

static NSUserDefaults *prefs;
static BOOL enabled;
static BOOL haptics;
static UISwipeGestureRecognizerDirection direction;
static NSHashTable<UISwipeGestureRecognizer *> *recognizers;

// The view the current Control Center touch landed on, used to tell the
// connectivity module's buttons apart
static __weak UIView *touchedView;
static NSString *pendingLink;

// Link key -> Settings URL. "music" is handled separately since it opens an
// app.
static NSDictionary<NSString *, NSString *> *settingsURLs(void) {
  static NSDictionary *urls;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    urls = @{
      @"wifi" : @"prefs:root=WIFI",
      @"bluetooth" : @"prefs:root=Bluetooth",
      @"cellular" : @"prefs:root=MOBILE_DATA_SETTINGS_ID",
      @"hotspot" : @"prefs:root=INTERNET_TETHERING",
      @"airdrop" : @"prefs:root=General&path=AirDrop",
      @"vpn" : @"prefs:root=General&path=VPN",
      @"focus" : @"prefs:root=DO_NOT_DISTURB",
      @"lowpower" : @"prefs:root=BATTERY_USAGE",
    };
  });
  return urls;
}

static UISwipeGestureRecognizerDirection
directionForGesture(CCLGesture gesture) {
  switch (gesture) {
  case CCLGestureSwipeLeft:
    return UISwipeGestureRecognizerDirectionLeft;
  case CCLGestureSwipeUp:
    return UISwipeGestureRecognizerDirectionUp;
  case CCLGestureSwipeDown:
    return UISwipeGestureRecognizerDirectionDown;
  default:
    return UISwipeGestureRecognizerDirectionRight;
  }
}

static void loadPrefs(void) {
  enabled = [prefs boolForKey:@"enabled"];
  haptics = [prefs boolForKey:@"haptics"];
  direction = directionForGesture([prefs integerForKey:@"gesture"]);
  for (UISwipeGestureRecognizer *recognizer in recognizers) {
    recognizer.direction = direction;
  }
}

static void prefsChanged(CFNotificationCenterRef center, void *observer,
                         CFStringRef name, const void *object,
                         CFDictionaryRef userInfo) {
  dispatch_async(dispatch_get_main_queue(), ^{
    loadPrefs();
  });
}

// Connectivity buttons are separate view controllers inside one module
// (CCUIConnectivityWifiViewController etc.), so walk up from the touched view
static NSString *connectivityLinkForView(UIView *view,
                                         UIViewController *container) {
  // Link keys double as the class name fragment to look for
  NSArray<NSString *> *links =
      @[ @"wifi", @"bluetooth", @"cellular", @"hotspot", @"airdrop", @"vpn" ];
  for (UIResponder *responder = view; responder && responder != container;
       responder = responder.nextResponder) {
    if (![responder isKindOfClass:UIViewController.class])
      continue;
    NSString *name = NSStringFromClass(responder.class).lowercaseString;
    for (NSString *link in links) {
      if ([name containsString:link])
        return link;
    }
  }
  return nil;
}

static NSString *
linkForModule(CCUIContentModuleContainerViewController *container,
              UIView *view) {
  NSString *module = container.moduleIdentifier.lowercaseString;
  if (!module)
    return nil;

  if ([module containsString:@"connectivity"])
    return connectivityLinkForView(view, container);
  if ([module containsString:@"nowplaying"])
    return @"music";
  if ([module containsString:@"focus"] ||
      [module containsString:@"donotdisturb"])
    return @"focus";
  if ([module containsString:@"lowpower"])
    return @"lowpower";
  return nil;
}

static NSString *musicAppBundleID(void) {
  NSString *app = [prefs stringForKey:@"musicApp"];
  if (app.length && ![app isEqualToString:@"nowplaying"])
    return app;
  SBApplication *nowPlaying =
      [[% c(SBMediaController) sharedInstance] nowPlayingApplication];
  return nowPlaying.bundleIdentifier ?: @"com.apple.Music";
}

static void openLink(NSString *link) {
  NSString *bundleID;
  NSURL *url;
  if ([link isEqualToString:@"music"]) {
    bundleID = musicAppBundleID();
  } else {
    bundleID = @"com.apple.Preferences";
    url = [NSURL URLWithString:settingsURLs()[link]];
    if (!url)
      return;
  }

  [[% c(SBControlCenterController) sharedInstance] dismissAnimated:YES
                                                        completion:nil];

  // Unlocks (prompting for the passcode) when invoked from the lock screen
  NSDictionary *options = @{FBSOpenApplicationOptionKeyUnlockDevice : @YES};
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    FBSSystemService *service = [FBSSystemService sharedService];
    if (url) {
      [service openURL:url
           application:bundleID
               options:options
            clientPort:[service createClientPort]
            withResult:nil];
    } else {
      [service openApplication:bundleID options:options withResult:nil];
    }
  });
}

@interface CCLGestureHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)sharedInstance;
@end

@implementation CCLGestureHandler

+ (instancetype)sharedInstance {
  static CCLGestureHandler *instance;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    instance = [self new];
  });
  return instance;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
       shouldReceiveTouch:(UITouch *)touch {
  touchedView = touch.view;
  return enabled;
}

- (BOOL)gestureRecognizerShouldBegin:(UISwipeGestureRecognizer *)recognizer {
  pendingLink = nil;
  if (!enabled)
    return NO;

  // A module's root view's next responder is its container view controller
  CCUIContentModuleContainerViewController *container =
      (id)recognizer.view.nextResponder;
  if (![container isKindOfClass: % c(CCUIContentModuleContainerViewController)])
    return NO;

  // Expanded modules have scrubbers and lists the swipe would fight with,
  // except connectivity, whose expanded view is just more buttons (AirDrop,
  // Personal Hotspot)
  BOOL expanded = [container respondsToSelector:@selector(isExpanded)] &&
                  container.isExpanded;
  if (expanded && ![container.moduleIdentifier.lowercaseString
                      containsString:@"connectivity"])
    return NO;

  NSString *link = linkForModule(container, touchedView);
  if (!link) {
    NSLog(@"[CCLinker] No link for module %@ (view: %@)",
          container.moduleIdentifier, touchedView.class);
    return NO;
  }
  if (![prefs boolForKey:link])
    return NO;

  pendingLink = link;
  return YES;
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer {
  if (recognizer.state != UIGestureRecognizerStateRecognized || !pendingLink)
    return;
  if (haptics) {
    [[[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
  }
  openLink(pendingLink);
  pendingLink = nil;
}

@end

% hook CCUIContentModuleContainerViewController

    - (void)viewDidLoad {
  % orig;
  CCLGestureHandler *handler = [CCLGestureHandler sharedInstance];
  UISwipeGestureRecognizer *swipe =
      [[UISwipeGestureRecognizer alloc] initWithTarget:handler
                                                action:@selector(handleSwipe:)];
  swipe.direction = direction;
  swipe.delegate = handler;
  [self.view addGestureRecognizer:swipe];
  [recognizers addObject:swipe];
}

% end

    % ctor {
  prefs = [[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain];
  [prefs registerDefaults:@{
    @"enabled" : @YES,
    @"haptics" : @YES,
    @"gesture" : @(CCLGestureSwipeRight),
    @"musicApp" : @"nowplaying",
    @"wifi" : @YES,
    @"bluetooth" : @YES,
    @"cellular" : @YES,
    @"hotspot" : @YES,
    @"airdrop" : @YES,
    @"vpn" : @YES,
    @"music" : @YES,
    @"focus" : @YES,
    @"lowpower" : @YES,
  }];
  recognizers = [NSHashTable weakObjectsHashTable];
  loadPrefs();

  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                  NULL, prefsChanged,
                                  CFSTR(kPrefsChangedNotification), NULL,
                                  CFNotificationSuspensionBehaviorCoalesce);

  % init;
}
