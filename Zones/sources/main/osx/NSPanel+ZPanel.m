//
//  NSPanel+ZPanel.m
//  Seriously
//
//  Created by Jonathan Sand on 3/31/19.
//  Copyright © 2019 Zones. All rights reserved.
//

#import "NSPanel+ZPanel.h"

@implementation NSPanel (ZPanel)


- (void)setDirectoryAndExtensionFor:(NSURL *)url {
    NSSavePanel     *panel = (NSSavePanel *)self;
    NSURL               *u = url;
    
    if (!u.hasDirectoryPath) {
        u                  = u.URLByDeletingLastPathComponent;
    }
    
    panel.directoryURL     = u;
    panel.allowedFileTypes = @[url.pathExtension];
    
    [[NSFileManager defaultManager] changeCurrentDirectoryPath: u.path];
}


- (void)setAllowedFileType:(NSString *)fileType {
    NSSavePanel     *panel = (NSSavePanel *)self;
    panel.allowedFileTypes = @[fileType];
}

@end
