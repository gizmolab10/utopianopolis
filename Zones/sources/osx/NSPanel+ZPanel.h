//
//  NSPanel+ZPanel.h
//  Seriously
//
//  Created by Jonathan Sand on 3/31/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//


@import Cocoa;


@interface NSPanel (ZPanel)

- (void)setDirectoryAndExtensionFor:(NSURL *)url;
- (void)setAllowedFileType:(NSString *)fileType;

@end
