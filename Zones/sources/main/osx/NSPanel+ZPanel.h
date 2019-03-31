//
//  NSPanel+ZPanel.h
//  Thoughtful
//
//  Created by Jonathan Sand on 3/31/19.
//  Copyright © 2019 Zones. All rights reserved.
//


@import Cocoa;


@interface NSPanel (ZPanel)

- (void)setDirectoryAndExtensionFor:(NSURL *)url;
- (void)setAllowedFileType:(NSString *)fileType;

@end
