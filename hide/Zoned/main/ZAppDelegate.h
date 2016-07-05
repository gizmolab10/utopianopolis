//
//  ZAppDelegate.h
//  Zoned
//
//  Created by Jonathan Sand on 6/30/16.
//  Copyright © 2016 Zoned. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@interface ZAppDelegate : NSObject <NSApplicationDelegate>


@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;


@end

