#import "Settings.h"
#import "DeviceModels.h"
#import "Logger.h"
#import "Utils.h"
#import "Themes.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface BunnySettingsViewController () <UIDocumentPickerDelegate>
- (void)showThemeLibrary;
- (void)importThemeJSON;
- (void)disableActiveTheme;
- (void)applyThemeAtURL:(NSURL *)themeURL;
- (void)copyDiagnostics;
@end

static NSURL *themeDirectoryURL(void) {
    NSURL *directory = [getRainDirectory() URLByAppendingPathComponent:@"themes" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    return directory;
}

static BOOL validateThemeData(NSData *data, NSDictionary **themeOut, NSString **reasonOut) {
    if (!data.length || data.length > 2 * 1024 * 1024) {
        if (reasonOut) *reasonOut = @"Theme JSON must be between 1 byte and 2 MB.";
        return NO;
    }

    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![object isKindOfClass:[NSDictionary class]]) {
        if (reasonOut) *reasonOut = @"The file is not a valid JSON theme object.";
        return NO;
    }

    NSDictionary *theme = (NSDictionary *)object;
    NSDictionary *themeData = [theme[@"data"] isKindOfClass:[NSDictionary class]] ? theme[@"data"] : nil;
    NSNumber *rawSpec = themeData[@"spec"];
    NSInteger spec = rawSpec ? rawSpec.integerValue : 3;
    NSDictionary *semantic = nil;

    if (spec == 3) {
        NSDictionary *main = [theme[@"main"] isKindOfClass:[NSDictionary class]] ? theme[@"main"] : nil;
        semantic = [main[@"semantic"] isKindOfClass:[NSDictionary class]] ? main[@"semantic"] : nil;
    } else if (spec == 2) {
        semantic = [themeData[@"semanticColors"] isKindOfClass:[NSDictionary class]] ? themeData[@"semanticColors"] : nil;
    } else if (spec == 1) {
        semantic = [themeData[@"theme_color_map"] isKindOfClass:[NSDictionary class]] ? themeData[@"theme_color_map"] : nil;
    } else {
        if (reasonOut) *reasonOut = @"Unsupported theme schema. Supported theme specs are 1, 2, and 3.";
        return NO;
    }

    if (!semantic.count) {
        if (reasonOut) *reasonOut = @"The JSON does not contain a supported semantic color map.";
        return NO;
    }

    if (themeOut) *themeOut = theme;
    return YES;
}

static NSString *safeThemeName(NSString *name) {
    NSString *base = [[name stringByDeletingPathExtension] stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!base.length) base = @"Imported Theme";
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ."] invertedSet];
    base = [[base componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    base = [base stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    return base.length ? base : @"Imported-Theme";
}

@implementation BunnySettingsViewController

- (instancetype)initWithVersion:(NSString *)version {
    self = [super init];
    if (self) {
        self.title = [NSString stringWithFormat:@"RainTweak v%@ Recovery Menu", version];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                          style:UITableViewStyleInsetGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate                                  = self;
    tableView.dataSource                                = self;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Recovery & Maintenance" : @"Appearance, Tools & Diagnostics";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Original recovery actions are preserved. Destructive actions ask for confirmation.";
    }
    return @"Theme JSON is validated before import. A backup is kept before replacing the active theme.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 10 : 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"Cell"];
    }

    NSArray *options = indexPath.section == 0 ? @[
        @{@"title" : @"Toggle Safe Mode", @"icon" : @"shield", @"destructive" : @NO},
        @{@"title" : @"Refetch Bundle", @"icon" : @"arrow.triangle.2.circlepath", @"destructive" : @NO},
        @{@"title" : @"Switch Bundle Version", @"icon" : @"arrow.triangle.2.circlepath.circle", @"destructive" : @NO},
        @{@"title" : @"Load Custom Bundle", @"icon" : @"link.badge.plus", @"destructive" : @NO},
        @{@"title" : @"Reset Bundle", @"icon" : @"arrow.counterclockwise", @"destructive" : @YES},
        @{@"title" : @"Delete All Plugins", @"icon" : @"trash", @"destructive" : @YES},
        @{@"title" : @"Delete All Themes", @"icon" : @"trash", @"destructive" : @YES},
        @{@"title" : @"Delete All Mod Data", @"icon" : @"trash.fill", @"destructive" : @YES},
        @{@"title" : @"Open App Folder", @"icon" : @"folder", @"destructive" : @NO},
        @{@"title" : @"Open GitHub Issue", @"icon" : @"exclamationmark.bubble", @"destructive" : @NO}
    ] : @[
        @{@"title" : @"Browse Theme Library", @"icon" : @"paintpalette", @"destructive" : @NO},
        @{@"title" : @"Import Theme JSON", @"icon" : @"square.and.arrow.down", @"destructive" : @NO},
        @{@"title" : @"Restore Bundle Backup", @"icon" : @"arrow.uturn.backward.circle", @"destructive" : @NO},
        @{@"title" : @"Copy Diagnostics", @"icon" : @"doc.on.clipboard", @"destructive" : @NO}
    ];

    NSDictionary *option = options[indexPath.row];
    cell.textLabel.text  = option[@"title"];

    UIImageConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:22
                                                        weight:UIImageSymbolWeightRegular];
    UIImage *icon        = [UIImage systemImageNamed:option[@"icon"] withConfiguration:config];
    cell.imageView.image = icon;
    cell.imageView.tintColor =
        [option[@"destructive"] boolValue] ? UIColor.systemRedColor : UIColor.systemBlueColor;

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = isSafeModeEnabled() ? @"Disable Safe Mode" : @"Enable Safe Mode";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0:
                [self showThemeLibrary];
                break;
            case 1:
                [self importThemeJSON];
                break;
            case 2:
                if (restoreBundleFromBackup()) {
                    UIAlertController *alert = [UIAlertController
                        alertControllerWithTitle:@"Bundle Restored"
                                         message:@"The previous bundle was restored. Reload Discord to use it."
                                  preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Later"
                                                              style:UIAlertActionStyleCancel
                                                            handler:nil]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Reload Now"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) { reloadApp(self); }]];
                    [self presentViewController:alert animated:YES completion:nil];
                } else {
                    showErrorAlert(@"No Backup Found", @"There is no saved bundle backup to restore.", nil);
                }
                break;
            case 3:
                [self copyDiagnostics];
                break;
        }
        return;
    }

    if (indexPath.row == 0) {
        toggleSafeMode();
        return;
    }

    if (indexPath.row == 2) {
        showBundleSelector(self);
        return;
    }

    void (^performAction)(void) = ^{
        switch (indexPath.row) {
        case 1:
            refetchBundle(self);
            break;
        case 3:
            [self loadCustomBundle];
            break;
        case 4:
            resetCustomBundleURL(self);
            break;
        case 5:
            deletePluginsAndReload(self);
            break;
        case 6:
            deleteThemesAndReload(self);
            break;
        case 7:
            deleteAllData(self);
            break;
        case 8:
            [self openDocumentsDirectory];
            break;
        case 9:
            [self openGitHub];
            break;
        }
    };

    if (indexPath.row != 3 && indexPath.row != 8 && indexPath.row != 9) {
        NSString *actionText;
        switch (indexPath.row) {
        case 1:
            actionText = @"refetch the bundle";
            break;
        case 4:
            actionText = @"reset the bundle";
            break;
        case 5:
            actionText = @"delete all plugins";
            break;
        case 6:
            actionText = @"delete all themes";
            break;
        case 7:
            actionText = @"delete all mod data";
            break;
        default:
            actionText = @"perform this action";
            break;
        }

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Confirm Action"
                             message:[NSString stringWithFormat:@"Are you sure you want to %@?",
                                                                actionText]
                      preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [alert addAction:[UIAlertAction
                             actionWithTitle:@"Confirm"
                                       style:UIAlertActionStyleDestructive
                                     handler:^(UIAlertAction *action) { performAction(); }]];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        performAction();
    }
}

- (void)openDocumentsDirectory {
    if (isJailbroken) {
        NSString *filzaPath = [NSString stringWithFormat:@"filza://view%@", getRainDirectory().path];
        NSURL *filzaURL = [NSURL URLWithString:[filzaPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
        if ([[UIApplication sharedApplication] canOpenURL:filzaURL]) {
            [[UIApplication sharedApplication] openURL:filzaURL options:@{} completionHandler:nil];
            return;
        }
    }
    
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsUrl = [paths firstObject];
    
    NSString *sharedPath = [NSString stringWithFormat:@"shareddocuments://%@", documentsUrl.path];
    NSURL *sharedUrl = [NSURL URLWithString:sharedPath];
    
    [[UIApplication sharedApplication] openURL:sharedUrl options:@{} completionHandler:nil];
}

- (void)openGitHub {
    UIDevice *device      = [UIDevice currentDevice];
    NSString *deviceId    = getDeviceIdentifier();
    NSString *deviceModel = DEVICE_MODELS[deviceId] ?: deviceId;
    NSString *appVersion =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

    NSString *body =
        [NSString stringWithFormat:@"### Device Information\n"
                                    "- Device: %@\n"
                                    "- iOS Version: %@\n"
                                    "- Tweak Version: %@\n"
                                    "- App Version: %@ (%@)\n"
                                    "- Jailbroken: %@\n\n"
                                    "### Issue Description\n"
                                    "<!-- Describe your issue here -->\n\n"
                                    "### Steps to Reproduce\n"
                                    "1. \n2. \n3. \n\n"
                                    "### Expected Behavior\n\n"
                                    "### Actual Behavior\n",
                                   deviceModel, device.systemVersion, PACKAGE_VERSION, appVersion,
                                   buildNumber, isJailbroken ? @"Yes" : @"No"];

    NSString *encodedTitle = [@"bug(iOS): "
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                               URLQueryAllowedCharacterSet]];
    NSString *encodedBody =
        [body stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                                     URLQueryAllowedCharacterSet]];

NSString *urlString = [NSString stringWithFormat:@"https://codeberg.org/raincord/RainTweak/issues/new?title=%@&body=%@",
                     encodedTitle, encodedBody];

    NSURL *url          = [NSURL URLWithString:urlString];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}


- (void)showThemeLibrary {
    NSURL *directory = themeDirectoryURL();
    NSError *listingError = nil;
    NSArray<NSURL *> *contents = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:directory
        includingPropertiesForKeys:nil
        options:NSDirectoryEnumerationSkipsHiddenFiles
        error:&listingError];

    NSMutableArray<NSURL *> *themeURLs = [NSMutableArray array];
    for (NSURL *url in contents ?: @[]) {
        if ([[url.pathExtension lowercaseString] isEqualToString:@"json"]) {
            [themeURLs addObject:url];
        }
    }
    [themeURLs sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent localizedCaseInsensitiveCompare:b.lastPathComponent];
    }];

    NSString *message = [NSString stringWithFormat:
        @"%lu JSON theme(s) found in Documents/rain/themes. Choose one to activate it.",
        (unsigned long)themeURLs.count];
    if (listingError) {
        message = [message stringByAppendingFormat:@"\n\nFolder error: %@", listingError.localizedDescription];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Theme Library"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    if (!themeURLs.count) {
        UIAlertAction *empty = [UIAlertAction actionWithTitle:@"No themes imported yet"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil];
        empty.enabled = NO;
        [alert addAction:empty];
    }

    for (NSURL *themeURL in themeURLs) {
        NSString *title = [themeURL.lastPathComponent stringByDeletingPathExtension];
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self applyThemeAtURL:themeURL];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Disable Active Theme"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [self disableActiveTheme];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                        CGRectGetMidY(self.view.bounds), 1, 1);
        popover.permittedArrowDirections = 0;
    }
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)disableActiveTheme {
    NSURL *activeURL = [NSURL fileURLWithPath:CURRENT_THEME];
    NSURL *backupURL = [NSURL fileURLWithPath:[CURRENT_THEME stringByAppendingString:@".backup"]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:activeURL.path]) {
        showErrorAlert(@"No Active Theme", @"There is no active theme override to disable.", nil);
        return;
    }

    NSError *error = nil;
    NSData *currentTheme = [NSData dataWithContentsOfURL:activeURL options:0 error:&error];
    if (!currentTheme || ![currentTheme writeToURL:backupURL options:NSDataWritingAtomic error:&error]) {
        showErrorAlert(@"Theme Backup Failed",
                       error.localizedDescription ?: @"The active theme could not be backed up.",
                       nil);
        return;
    }
    if (![fileManager removeItemAtURL:activeURL error:&error]) {
        showErrorAlert(@"Theme Disable Failed",
                       error.localizedDescription ?: @"Could not remove the active theme override.",
                       nil);
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Theme Disabled"
                         message:@"The active theme override was removed. Reload Discord to restore its default colors."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reload Now"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) { reloadApp(self); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)importThemeJSON {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeJSON, UTTypePlainText]
                                                                    asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)applyThemeAtURL:(NSURL *)themeURL {
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:themeURL options:0 error:&readError];
    NSString *reason = nil;
    if (!data || !validateThemeData(data, NULL, &reason)) {
        showErrorAlert(@"Theme Not Applied",
                       reason ?: readError.localizedDescription ?: @"Unable to read the selected theme.",
                       nil);
        return;
    }

    NSURL *activeURL = [NSURL fileURLWithPath:CURRENT_THEME];
    NSURL *backupURL = [NSURL fileURLWithPath:[CURRENT_THEME stringByAppendingString:@".backup"]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtURL:[activeURL URLByDeletingLastPathComponent]
          withIntermediateDirectories:YES attributes:nil error:nil];

    if ([fileManager fileExistsAtPath:activeURL.path]) {
        NSError *backupError = nil;
        NSData *oldTheme = [NSData dataWithContentsOfURL:activeURL options:0 error:&backupError];
        if (!oldTheme || ![oldTheme writeToURL:backupURL options:NSDataWritingAtomic error:&backupError]) {
            showErrorAlert(@"Theme Backup Failed",
                           backupError.localizedDescription ?: @"The current theme could not be backed up.",
                           nil);
            return;
        }
    }

    NSError *writeError = nil;
    if (![data writeToURL:activeURL options:NSDataWritingAtomic error:&writeError]) {
        showErrorAlert(@"Theme Apply Failed",
                       writeError.localizedDescription ?: @"Could not save the active theme.",
                       nil);
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Theme Saved"
                         message:[NSString stringWithFormat:@"%@ is now the active theme. Reload Discord to apply all colors.",
                                                            themeURL.lastPathComponent]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reload Now"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) { reloadApp(self); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
 didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *sourceURL = urls.firstObject;
    if (!sourceURL) return;

    if (![[sourceURL.pathExtension lowercaseString] isEqualToString:@"json"]) {
        showErrorAlert(@"Unsupported File", @"Choose a .json theme file.", nil);
        return;
    }

    BOOL didAccess = [sourceURL startAccessingSecurityScopedResource];
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:&readError];
    if (didAccess) [sourceURL stopAccessingSecurityScopedResource];

    NSDictionary *theme = nil;
    NSString *reason = nil;
    if (!data || !validateThemeData(data, &theme, &reason)) {
        showErrorAlert(@"Invalid Theme",
                       reason ?: readError.localizedDescription ?: @"The file could not be read.",
                       nil);
        return;
    }

    NSString *baseName = safeThemeName(sourceURL.lastPathComponent);
    NSString *suffix = [[[NSUUID UUID] UUIDString] substringToIndex:8];
    NSString *fileName = [NSString stringWithFormat:@"%@-%@.json", baseName, suffix];
    NSURL *destinationURL = [themeDirectoryURL() URLByAppendingPathComponent:fileName];
    NSError *writeError = nil;
    if (![data writeToURL:destinationURL options:NSDataWritingAtomic error:&writeError]) {
        showErrorAlert(@"Import Failed", writeError.localizedDescription ?: @"Could not save the theme.", nil);
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Theme Imported"
                         message:@"The theme was validated and saved to your local theme library."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate Now"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self applyThemeAtURL:destinationURL];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)copyDiagnostics {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *rainDirectory = getRainDirectory();
    NSURL *bundleURL = [rainDirectory URLByAppendingPathComponent:@"bundle.js"];
    NSURL *pluginsURL = [rainDirectory URLByAppendingPathComponent:@"plugins" isDirectory:YES];
    NSURL *themesURL = themeDirectoryURL();
    NSURL *currentThemeURL = [NSURL fileURLWithPath:CURRENT_THEME];

    NSArray *plugins = [fileManager contentsOfDirectoryAtURL:pluginsURL
                                  includingPropertiesForKeys:nil
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];
    NSArray *themes = [fileManager contentsOfDirectoryAtURL:themesURL
                                 includingPropertiesForKeys:nil
                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                      error:nil];
    NSDictionary *bundleAttributes = [fileManager attributesOfItemAtPath:bundleURL.path error:nil];
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"Unknown";
    NSString *buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"Unknown";

    NSString *diagnostics = [NSString stringWithFormat:
        @"RainTweak Diagnostics\n"
         "Tweak version: %@\n"
         "Discord version: %@ (%@)\n"
         "iOS: %@\n"
         "Device: %@\n"
         "Jailbroken: %@\n"
         "Safe mode: %@\n"
         "Bundle cache present: %@\n"
         "Bundle cache bytes: %@\n"
         "Imported plugins: %lu\n"
         "Imported themes: %lu\n"
         "Active theme file present: %@\n",
        PACKAGE_VERSION, appVersion, buildNumber, UIDevice.currentDevice.systemVersion,
        DEVICE_MODELS[getDeviceIdentifier()] ?: getDeviceIdentifier(),
        isJailbroken ? @"Yes" : @"No",
        isSafeModeEnabled() ? @"Enabled" : @"Disabled",
        [fileManager fileExistsAtPath:bundleURL.path] ? @"Yes" : @"No",
        bundleAttributes[NSFileSize] ?: @0,
        (unsigned long)plugins.count, (unsigned long)themes.count,
        [fileManager fileExistsAtPath:currentThemeURL.path] ? @"Yes" : @"No"];

    UIPasteboard.generalPasteboard.string = diagnostics;
    showErrorAlert(@"Diagnostics Copied",
                   @"The diagnostic summary is on your clipboard. Review it before sharing.",
                   nil);
}

- (void)loadCustomBundle {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Load Custom Bundle"
                                            message:@"Enter the URL for your custom bundle:"
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder            = @"https://example.com/bundle.js";
        textField.keyboardType           = UIKeyboardTypeURL;
        textField.autocorrectionType     = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    UIAlertAction *loadAction = [UIAlertAction
        actionWithTitle:@"Load"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    NSString *urlString = alert.textFields.firstObject.text;
                    if (urlString.length == 0) {
                        [self presentViewController:alert animated:YES completion:nil];
                        showErrorAlert(@"Invalid URL", @"Please enter a URL", nil);
                        return;
                    }

                    NSURL *url = [NSURL URLWithString:urlString];
                    if (!url || !url.scheme || !url.host) {
                        [self presentViewController:alert animated:YES completion:nil];
                        showErrorAlert(
                            @"Invalid URL",
                            @"Please enter a valid URL (e.g., https://example.com/bundle.js)", nil);
                        return;
                    }

                    if (![url.scheme isEqualToString:@"http"] &&
                        ![url.scheme isEqualToString:@"https"]) {
                        [self presentViewController:alert animated:YES completion:nil];
                        showErrorAlert(@"Invalid URL", @"URL must start with http:// or https://",
                                       nil);
                        return;
                    }

                    NSURLSession *session =
                        [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration
                                                                   defaultSessionConfiguration]];
                    [[session
                          dataTaskWithURL:url
                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (error) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(
                                        @"Connection Error",
                                        [NSString stringWithFormat:@"Could not reach URL: %@",
                                                                   error.localizedDescription],
                                        nil);
                                    return;
                                }

                                if (!data) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(@"Error", @"No data received from URL", nil);
                                    return;
                                }

                                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                if (httpResponse.statusCode != 200) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(
                                        @"Error",
                                        [NSString stringWithFormat:@"Server returned error %ld",
                                                                   (long)httpResponse.statusCode],
                                        nil);
                                    return;
                                }

                                NSString *contentType =
                                    httpResponse.allHeaderFields[@"Content-Type"];
                                if (![contentType containsString:@"javascript"] &&
                                    ![contentType containsString:@"text"]) {
                                    [self presentViewController:alert animated:YES completion:nil];
                                    showErrorAlert(@"Invalid Content",
                                                   @"URL must point to a JavaScript file", nil);
                                    return;
                                }

                                setCustomBundleURL(url, self);
                                removeCachedBundle();
                                gracefulExit(self);
                            });
                        }] resume];
                }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:loadAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

void showSettingsSheet(void) {
    BunnySettingsViewController *settingsVC =
        [[BunnySettingsViewController alloc] initWithVersion:PACKAGE_VERSION];

    UINavigationController *navController =
        [[UINavigationController alloc] initWithRootViewController:settingsVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;

    UIBarButtonItem *doneButton =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:settingsVC
                                                      action:@selector(dismiss)];
    settingsVC.navigationItem.rightBarButtonItem = doneButton;

    UIWindow *window = nil;
    NSSet *scenes    = [[UIApplication sharedApplication] connectedScenes];
    for (UIScene *scene in scenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = ((UIWindowScene *)scene).windows.firstObject;
            break;
        }
    }

    if (!window) {
        window = [[UIApplication sharedApplication] windows].firstObject;
    }

    if (window && window.rootViewController) {
        [window.rootViewController presentViewController:navController animated:YES completion:nil];
    }
}

@end
