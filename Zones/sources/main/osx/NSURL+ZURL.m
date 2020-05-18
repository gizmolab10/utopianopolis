//
//  NSURL+ZURL.m
//  Seriously
//
//  Created by Jonathan Sand on 3/31/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

#import "NSURL+ZURL.h"

@implementation NSURL (ZURL)

- (BOOL)openSecurely {
    NSError *oError;
    NSData *fileData = [self bookmarkDataWithOptions:NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:NULL relativeToURL:NULL error:&oError];
    
    if (oError == nil) {
        BOOL isStale;
        NSURL *fileURL = [NSURL URLByResolvingBookmarkData:fileData options:NSURLBookmarkResolutionWithoutUI relativeToURL:NULL bookmarkDataIsStale:&isStale error:&oError];
    
        if (oError == nil) {
            [fileURL startAccessingSecurityScopedResource];
            [[NSWorkspace sharedWorkspace] openURL: fileURL];
            [fileURL stopAccessingSecurityScopedResource];
            
            return YES;
        }
    }
    
    return NO;
}

@end
