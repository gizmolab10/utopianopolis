//
//  ZSingletons.swift
//  Zones
//
//  Created by Jonathan Sand on 7/5/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


let sharedCoreDataManager = ZCoreDataManager()
let     sharedApplication = ZApplication.sharedApplication()
let  managedObjectContext = sharedCoreDataManager.managedObjectContext

