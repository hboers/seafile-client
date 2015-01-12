#include "utils-mac.h"

#include <Cocoa/Cocoa.h>
#include <AvailabilityMacros.h>
#include <xpc/connection.h>
#include <QString>

#if !__has_feature(objc_arc)
#error this file must be built with ARC support
#endif

// borrowed from AvailabilityMacros.h
#ifndef MAC_OS_X_VERSION_10_10
#define MAC_OS_X_VERSION_10_10      101000
#endif

#define kFSpluginBundleId "com.seafile.seafile-client.fsplugin"

namespace utils {
namespace mac {

namespace {
static bool checked = false;
static double scaleFactor = 1.0;
}

inline static void checkFactor() {
    if (!checked){
#if (__MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7)
        if ([[NSScreen mainScreen] respondsToSelector: @selector(backingScaleFactor)])
            scaleFactor = [[NSScreen mainScreen] backingScaleFactor];
#else
        scaleFactor = 1.0;
#endif
        checked = true;
    }
}

int isHiDPI() {
    checkFactor();
    return (scaleFactor > 1.0);
}

double getScaleFactor() {
    checkFactor();
    return scaleFactor;
}

//TransformProcessType is not encouraged to use, aha
//Sorry but not functional for OSX 10.7
void setDockIconStyle(bool hidden) {
    //https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSRunningApplication_Class/Reference/Reference.html
    if (hidden) {
        [[NSApplication sharedApplication] setActivationPolicy: NSApplicationActivationPolicyAccessory];
    } else {
        [[NSApplication sharedApplication] setActivationPolicy: NSApplicationActivationPolicyRegular];
    }
}

// Yosemite uses a new url format called fileId url, use this helper to transform
// it to the old style.
// https://bugreports.qt-project.org/browse/QTBUG-40449
// NSString *fileIdURL = @"file:///.file/id=6571367.1000358";
// NSString *goodURL = [[NSURL URLWithString:fileIdURL] filePathURL];
QString get_path_from_fileId_url(const QString &url) {
    NSString *fileIdURL = [NSString stringWithCString:url.toUtf8().data()
                                    encoding:NSUTF8StringEncoding];
    NSURL *goodURL = [[NSURL URLWithString:fileIdURL] filePathURL];
    NSString *filePath = goodURL.path; // readonly

    QString retval = QString::fromUtf8([filePath UTF8String],
                                       [filePath lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    return retval;
}

// original idea come from growl framework
// http://growl.info/about
bool get_auto_start()
{
    NSURL *itemURL = [[NSBundle mainBundle] bundleURL];
    Boolean found = false;
    CFURLRef URLToToggle = (CFURLRef)CFBridgingRetain(itemURL);
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        UInt32 seed = 0U;
        NSArray *currentLoginItems = CFBridgingRelease((LSSharedFileListCopySnapshot(loginItems, &seed)));
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFBridgingRetain(itemObject);

            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFURLRef URL = NULL;
#if (__MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)
            CFErrorRef err;
            URL = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, &err);
            if (err) {
#else
            OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
            if (err == noErr) {
#endif
                found = CFEqual(URL, URLToToggle);
                CFRelease(URL);

                if (found)
                    break;
            }
        }
        CFRelease(loginItems);
    }
    return found;
}

void set_auto_start(bool enabled)
{
    NSURL *itemURL = [[NSBundle mainBundle] bundleURL];
    OSStatus status;
    CFURLRef URLToToggle = (CFURLRef)CFBridgingRetain(itemURL);
    LSSharedFileListItemRef existingItem = NULL;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, /*options*/ NULL);
    if(loginItems)
    {
        UInt32 seed = 0U;
        NSArray *currentLoginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seed));
        for (id itemObject in currentLoginItems) {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFBridgingRetain(itemObject);

            UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
            CFURLRef URL = NULL;
#if (__MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)
            CFErrorRef err;
            URL = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, &err);
            if (err) {
#else
            OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
            if (err == noErr) {
#endif
                Boolean found = CFEqual(URL, URLToToggle);
                CFRelease(URL);

                if (found) {
                    existingItem = item;
                    break;
                }
            }
        }

        if (enabled && (existingItem == NULL)) {
            NSString *displayName = @"Seafile Client";
            IconRef icon = NULL;
            FSRef ref;
            //TODO: replace the deprecated CFURLGetFSRef
            Boolean gotRef = CFURLGetFSRef(URLToToggle, &ref);
            if (gotRef) {
                status = GetIconRefFromFileInfo(&ref,
                                                /*fileNameLength*/ 0,
                                                /*fileName*/ NULL,
                                                kFSCatInfoNone,
                                                /*catalogInfo*/ NULL,
                                                kIconServicesNormalUsageFlag,
                                                &icon,
                                                /*outLabel*/ NULL);
                if (status != noErr)
                    icon = NULL;
            }

            LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst,
                  (CFStringRef)CFBridgingRetain(displayName), icon, URLToToggle,
                  /*propertiesToSet*/ NULL, /*propertiesToClear*/ NULL);
          } else if (!enabled && (existingItem != NULL))
              LSSharedFileListItemRemove(loginItems, existingItem);

        CFRelease(loginItems);
    }
}

void setSeafileDirectoryForFSplugin(const QString &path) {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@kFSpluginBundleId];
    NSString *filePath = [NSString stringWithCString:path.toUtf8().data()
                                    encoding:NSUTF8StringEncoding];
    NSURL *seafielDirectory = [NSURL fileURLWithPath:filePath isDirectory: TRUE];
    [sharedDefaults setURL: seafielDirectory forKey: @"SeafileDirectory"];
}

static xpc_connection_t fsplugin_connection;
static bool fsplugin_is_connected = false;
void startFSplugin() {
    if (!fsplugin_is_connected) {
        fsplugin_connection = xpc_connection_create(kFSpluginBundleId, NULL);

        xpc_connection_set_event_handler(fsplugin_connection,
                                         ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);

            if (type == XPC_TYPE_ERROR) {
                if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                }

                else if (event == XPC_ERROR_CONNECTION_INVALID) {
                    NSLog(@"connection invalid");
                    fsplugin_connection = nil;
                    fsplugin_is_connected = false;
                }

                else {
                    NSLog(@"Unknown XPC error.");
                }
            }
        });
        fsplugin_is_connected = true;
        xpc_connection_resume(fsplugin_connection);
    }
}

void stopFSplugin() {
    if (fsplugin_is_connected) {
        fsplugin_is_connected = false;
        xpc_connection_cancel(fsplugin_connection);
    }
}

} // namespace mac
} // namespace utils
