//
//  ZSingletons.swift
//  Zones
//
//  Created by Jonathan Sand on 7/5/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


public let         zonesManager = ZonesManager()
public let      coreDataManager = ZCoreDataManager()
public let    sharedApplication = ZApplication.sharedApplication()
public let managedObjectContext = coreDataManager.managedObjectContext

