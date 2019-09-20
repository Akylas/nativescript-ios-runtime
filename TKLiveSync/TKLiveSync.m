#include <Foundation/Foundation.h>
#include "TKLiveSync.h"
#include "unzip.h"

static void tryExtractLiveSyncArchive() {
    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString* liveSyncPath = [NSString pathWithComponents:@[ libraryPath, @"Application Support", @"LiveSync" ]];
    NSString* syncZipPath = [NSString pathWithComponents:@[ liveSyncPath, @"sync.zip" ]];
    NSString* appPath = [NSString pathWithComponents:@[ liveSyncPath, @"app" ]];

    NSError* err;

    if ([fileManager fileExistsAtPath:syncZipPath]) {
        if ([fileManager fileExistsAtPath:appPath]) {
            [fileManager removeItemAtPath:appPath error:&err];
            if (err) {
                NSLog(@"Can't remove %@: %@", appPath, err);
            }
        }

        NSLog(@"Unzipping LiveSync folder. This could take a while...");
        NSDate* startDate = [NSDate date];
        int64_t unzippedFilesCount = unzip(syncZipPath.UTF8String, liveSyncPath.UTF8String);
        NSLog(@"Unzipped %lld entries in %fms.", unzippedFilesCount, -[startDate timeIntervalSinceNow] * 1000);

        [fileManager removeItemAtPath:syncZipPath error:&err];
        if (err) {
            NSLog(@"Can't remove %@: %@", syncZipPath, err);
        }
    }

    NSString* tnsModulesPath = [appPath stringByAppendingPathComponent:@"tns_modules"];

    // TRICKY: Check if real dir tns_modules exists. If it does not, or it is a symlink, the symlink has to be recreated.
    if ([fileManager fileExistsAtPath:appPath] && ![fileManager fileExistsAtPath:tnsModulesPath]) {
        NSLog(@"tns_modules folder not livesynced. Using tns_modules from the already deployed bundle...");

        // If tns_modules were a symlink, delete it so it can be linked again, this is necessary when relaunching the app from Xcode after lifesync, the app bundle seems to move.
        [fileManager removeItemAtPath:tnsModulesPath error:nil];

        NSError* error;
        NSString* bundleNativeScriptModulesPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"app/tns_modules"];
        if (![fileManager createSymbolicLinkAtPath: tnsModulesPath withDestinationPath: bundleNativeScriptModulesPath error:&error]) {
            NSLog(@"Failed to symlink tns_modules folder: %@", error);
        }
    }
}

static void trySetLiveSyncApplicationPath() {
    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString* liveSyncPath = [NSString pathWithComponents:@[ libraryPath, @"Application Support", @"LiveSync" ]];
    NSString* appPath = [NSString pathWithComponents:@[ liveSyncPath, @"app" ]];

    if (![fileManager fileExistsAtPath:appPath]) {
        return; // Don't change the app root folder
    }

    if (setenv("TNSBaseDir", liveSyncPath.UTF8String, 0) == -1) {
        perror("Could not set application path");
    }
}

void TNSInitializeLiveSync() {
    tryExtractLiveSyncArchive();
    trySetLiveSyncApplicationPath();
}
