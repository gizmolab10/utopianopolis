//
//  ZSingletons.swift
//  Zones
//
//  Created by Jonathan Sand on 7/5/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


let     sharedApplication = ZApplication.sharedApplication()
let sharedCoreDataManager = ZCoreDataManager.sharedCoreDataManager()
let  managedObjectContext = sharedCoreDataManager.managedObjectContext

