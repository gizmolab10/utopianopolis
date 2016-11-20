//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZTravelManager: NSObject {


    func travelAction(_ action: ZTravelAction) {
        switch action {
        case .mine:     cloudManager.storageMode = .mine;     break
        case .everyone: cloudManager.storageMode = .everyone; break
        }

        refresh()
    }


    func refresh() {
        zonesManager    .clear()
        widgetsManager  .clear()
        selectionManager.clear()

        stateManager.setupAndRun([ZSynchronizationState.restore.rawValue, ZSynchronizationState.root.rawValue])
    }
}
