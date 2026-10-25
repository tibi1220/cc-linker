#import "CCLApps.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSViewController.h>

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:
                 (NSString *)bundleIdentifier
                                               format:(int)format
                                                scale:(CGFloat)scale;
@end

static const CGFloat kIconSize = 29;

// Pushed by the music app cell: a searchable list of apps with their icons.
// Saving goes through the parent controller, which writes the preference and
// posts the specifier's PostNotification.
@interface CCLAppPickerController
    : PSViewController <UITableViewDataSource, UITableViewDelegate,
                        UISearchResultsUpdating>
@end

@implementation CCLAppPickerController {
  UITableView *_tableView;
  UISearchController *_searchController;
  NSArray<CCLApp *> *_apps;
  NSArray<CCLApp *> *_filteredApps;
  NSCache<NSString *, UIImage *> *_icons;
  NSString *_selectedBundleIdentifier;
}

- (void)loadView {
  _tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                            style:UITableViewStyleInsetGrouped];
  _tableView.dataSource = self;
  _tableView.delegate = self;
  _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  self.view = _tableView;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = self.specifier.name;

  _apps = CCLMusicApps();
  _filteredApps = _apps;
  _icons = [NSCache new];
  _selectedBundleIdentifier = [(PSListController *)self.parentController
                                  readPreferenceValue:self.specifier]
                                  ?: CCLNowPlayingValue;

  _searchController =
      [[UISearchController alloc] initWithSearchResultsController:nil];
  _searchController.searchResultsUpdater = self;
  _searchController.obscuresBackgroundDuringPresentation = NO;
  _searchController.searchBar.placeholder = @"Search Apps";
  self.navigationItem.searchController = _searchController;
  self.navigationItem.hidesSearchBarWhenScrolling = NO;
  self.definesPresentationContext = YES;
}

- (void)updateSearchResultsForSearchController:
    (UISearchController *)searchController {
  NSString *query = [searchController.searchBar.text
      stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  if (!query.length) {
    _filteredApps = _apps;
  } else {
    NSPredicate *predicate = [NSPredicate
        predicateWithBlock:^BOOL(CCLApp *app, NSDictionary *bindings) {
          return [app.name localizedCaseInsensitiveContainsString:query] ||
                 [app.bundleIdentifier
                     localizedCaseInsensitiveContainsString:query];
        }];
    _filteredApps = [_apps filteredArrayUsingPredicate:predicate];
  }
  [_tableView reloadData];
}

#pragma mark - Icons

static UIImage *iconSizedImage(UIImage *image) {
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
      initWithSize:CGSizeMake(kIconSize, kIconSize)];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [image drawInRect:CGRectMake(0, 0, kIconSize, kIconSize)];
  }];
}

// Settings-style glyph for the now playing entry
static UIImage *nowPlayingIcon(void) {
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
      initWithSize:CGSizeMake(kIconSize, kIconSize)];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [UIColor.systemPinkColor setFill];
    [[UIBezierPath
        bezierPathWithRoundedRect:CGRectMake(0, 0, kIconSize, kIconSize)
                     cornerRadius:7] fill];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration
        configurationWithPointSize:15
                            weight:UIImageSymbolWeightSemibold];
    UIImage *glyph = [[UIImage systemImageNamed:@"play.fill"
                              withConfiguration:config]
        imageWithTintColor:UIColor.whiteColor];
    [glyph drawAtPoint:CGPointMake((kIconSize - glyph.size.width) / 2,
                                   (kIconSize - glyph.size.height) / 2)];
  }];
}

static UIImage *placeholderIcon(void) {
  static UIImage *image;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
        initWithSize:CGSizeMake(kIconSize, kIconSize)];
    image =
        [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
          [UIColor.tertiarySystemFillColor setFill];
          [[UIBezierPath
              bezierPathWithRoundedRect:CGRectMake(0, 0, kIconSize, kIconSize)
                           cornerRadius:7] fill];
        }];
  });
  return image;
}

// Icons load off the main thread; the row is refreshed once its icon arrives
- (UIImage *)iconForApp:(CCLApp *)app {
  NSString *bundleIdentifier = app.bundleIdentifier;
  UIImage *icon = [_icons objectForKey:bundleIdentifier];
  if (icon)
    return icon;

  if ([bundleIdentifier isEqualToString:CCLNowPlayingValue]) {
    icon = nowPlayingIcon();
    [_icons setObject:icon forKey:bundleIdentifier];
    return icon;
  }

  CGFloat scale = self.traitCollection.displayScale ?: 3;
  __weak __typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    UIImage *image =
        [UIImage _applicationIconImageForBundleIdentifier:bundleIdentifier
                                                   format:0
                                                    scale:scale];
    if (!image)
      return;
    UIImage *sized = iconSizedImage(image);
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf didLoadIcon:sized forBundleIdentifier:bundleIdentifier];
    });
  });
  return placeholderIcon();
}

- (void)didLoadIcon:(UIImage *)icon
    forBundleIdentifier:(NSString *)bundleIdentifier {
  [_icons setObject:icon forKey:bundleIdentifier];
  NSUInteger row = [_filteredApps
      indexOfObjectPassingTest:^BOOL(CCLApp *app, NSUInteger index,
                                     BOOL *stop) {
        return [app.bundleIdentifier isEqualToString:bundleIdentifier];
      }];
  if (row == NSNotFound)
    return;
  UITableViewCell *cell = [_tableView
      cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
  cell.imageView.image = icon;
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return _filteredApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *const reuseIdentifier = @"App";
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:reuseIdentifier]
          ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:reuseIdentifier];

  CCLApp *app = _filteredApps[indexPath.row];
  BOOL nowPlaying = [app.bundleIdentifier isEqualToString:CCLNowPlayingValue];
  cell.textLabel.text = app.name;
  cell.detailTextLabel.text =
      nowPlaying ? @"Whichever app is playing, or Music" : app.bundleIdentifier;
  cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
  cell.imageView.image = [self iconForApp:app];
  cell.accessoryType =
      [app.bundleIdentifier isEqualToString:_selectedBundleIdentifier]
          ? UITableViewCellAccessoryCheckmark
          : UITableViewCellAccessoryNone;
  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  CCLApp *app = _filteredApps[indexPath.row];
  _selectedBundleIdentifier = app.bundleIdentifier;

  PSListController *parent = (PSListController *)self.parentController;
  [parent setPreferenceValue:app.bundleIdentifier specifier:self.specifier];
  [parent reloadSpecifier:self.specifier animated:NO];

  _searchController.active = NO;
  [self.navigationController popViewControllerAnimated:YES];
}

@end
