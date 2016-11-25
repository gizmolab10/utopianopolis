//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZTravelManager: NSObject {


    var storageRootZone: Zone! = Zone(record: nil, storageMode: cloudManager.storageMode)
    var        rootZone: Zone! = Zone(record: nil, storageMode: cloudManager.storageMode)


    func clear() {
        rootZone        = Zone(record: nil, storageMode: cloudManager.storageMode)
        storageRootZone = Zone(record: nil, storageMode: cloudManager.storageMode)
    }


    func travelAction(_ action: ZTravelAction) {
        switch action {
        case .mine:      cloudManager.storageMode = .mine;      break
        case .everyone:  cloudManager.storageMode = .everyone;  break
        case .bookmarks: cloudManager.storageMode = .bookmarks; break
        }

        refresh()
    }


    func refresh() {
        widgetsManager  .clear()
        selectionManager.clear()
        clear()
        operationsManager.setupAndRun([ZSynchronizationState.restore.rawValue, ZSynchronizationState.root.rawValue])
    }
}
