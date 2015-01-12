//
//  FinderSync.m
//  seafile-client-fsplugin
//
//  Created by Chilledheart on 1/10/15.
//  Copyright (c) 2015 Haiwen. All rights reserved.
//

#import "FinderSync.h"

@interface FinderSync ()

@property NSURL *seafileFolderURL;

@end

@implementation FinderSync

- (instancetype)init {
    self = [super init];

    NSLog(@"%s launched from %@ ; compiled at %s", __PRETTY_FUNCTION__, [[NSBundle mainBundle] bundlePath], __TIME__);

    // Get Seafile Directory from shared defaults
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.seafile.seafile-client.fsplugin"];
    NSLog(@"%s Seafile Directory is at %@",  __PRETTY_FUNCTION__, [sharedDefaults stringForKey:@"SeafileDirectory"]);

    // Set up the directory we are syncing.
    self.seafileFolderURL = [sharedDefaults URLForKey:@"SeafileDirectory"];
    if (self.seafileFolderURL == nil) {
        self.seafileFolderURL = [NSURL fileURLWithPath:@"/Users/Shared/untitled folder"]; // TODO remove it
    }

    [FIFinderSyncController defaultController].directoryURLs = [NSSet setWithObject:self.seafileFolderURL];

    // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameColorPanel] label:@"Status One" forBadgeIdentifier:@"One"];
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameCaution] label:@"Status Two" forBadgeIdentifier:@"Two"];

    return self;
}

#pragma mark - Primary Finder Sync protocol methods

- (void)beginObservingDirectoryAtURL:(NSURL *)url {
    // The user is now seeing the container's contents.
    // If they see it in more than one view at a time, we're only told once.
    NSLog(@"beginObservingDirectoryAtURL:%@", url.filePathURL);
}


- (void)endObservingDirectoryAtURL:(NSURL *)url {
    // The user is no longer seeing the container's contents.
    NSLog(@"endObservingDirectoryAtURL:%@", url.filePathURL);
}

- (void)requestBadgeIdentifierForURL:(NSURL *)url {
    NSLog(@"requestBadgeIdentifierForURL:%@", url.filePathURL);

    // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
    NSInteger whichBadge = [url.filePathURL hash] % 3;
    NSString* badgeIdentifier = @[@"", @"One", @"Two"][whichBadge];
    [[FIFinderSyncController defaultController] setBadgeIdentifier:badgeIdentifier forURL:url];
}

#pragma mark - Menu and toolbar item support

- (NSString *)toolbarItemName {
    return @"seafile-fsplugin";
}

- (NSString *)toolbarItemToolTip {
    return @"seafile-fsplugin: Click the toolbar item for a menu.";
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNameCaution];
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)whichMenu {
    // Produce a menu for the extension.
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [menu addItemWithTitle:@"Example Menu Item" action:@selector(sampleAction:) keyEquivalent:@""];

    return menu;
}

- (IBAction)sampleAction:(id)sender {
    NSURL* target = [[FIFinderSyncController defaultController] targetedURL];
    NSArray* items = [[FIFinderSyncController defaultController] selectedItemURLs];

    NSLog(@"sampleAction: menu item: %@, target = %@, items = ", [sender title], [target filePathURL]);
    [items enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"    %@", [obj filePathURL]);
    }];
}

@end

