//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZStorageMode: String {     ///// move this to cloud manager  //////////
    case bookmarks = "bookmarks"
    case everyone  = "everyone"
    case group     = "group"
    case mine      = "mine"
}


class ZTravelManager: NSObject {


    var    hereZone:  Zone!
    var storageZone:  Zone!
    var  cloudzones: [Zone] = []
    var   bookmarks: [Zone] = []
    let         key: String = "current storage mode"


    var storageMode: ZStorageMode {
        set { UserDefaults.standard.set(newValue.rawValue, forKey:key) }
        get {
            var mode: ZStorageMode? = nil

            if let           object = UserDefaults.standard.object(forKey:key) {
                mode                = ZStorageMode(rawValue: object as! String)
            }

            if mode == nil {
                mode                = .everyone
                self.storageMode    = mode!     // wow! this works
            }

            return mode!
        }
    }


    func setupBookmarks() {
        if storageMode == .bookmarks {
            hereZone.showChildren = true
            hereZone.zoneName     = "bookmarks"

            setupCloudZonesForAccessToStorage()
        }
    }


    func setup() {
        storageZone = Zone(record: nil, storageMode: storageMode)
        hereZone    = storageZone

        setupBookmarks()
    }


    func travel(_ block: (() -> Swift.Void)?) {
        widgetsManager    .clear()
        selectionManager  .clear()
        setup                   ()
        operationsManager.travel(block)
    }


    // MARK:- storage and cloud zones
    // MARK:-


    func setupCloudZonesForAccessToStorage() {
        addCloudZone("everyone", storageMode: .everyone)
        addCloudZone("mine",     storageMode: .mine)
    }


    func addCloudZone(_ name: String, storageMode: ZStorageMode) { // KLUDGE, perhaps use ordered set or dictionary
        let        zone = Zone(record: nil, storageMode: storageMode)
        zone.parentZone = hereZone
        zone.zoneName   = name
        zone.cloudZone  = name

        hereZone.children.append(zone)
    }


    func indexOfMode(_ mode: ZStorageMode) -> Int { // KLUDGE, perhaps use ordered set or dictionary
        switch mode {
        case .mine:     return  1
        case .everyone: return  0
        default:        return -1
        }
    }


    func travelWhereThisZonePoints(_ zone: Zone, atArrival: @escaping SignalClosure) {
        if storageMode == .bookmarks {
            if zone.cloudZone != nil, let mode = ZStorageMode(rawValue: zone.cloudZone!) {
                storageMode = mode // going in arrow to right

                travel {
                    atArrival(self.hereZone, .data)
                }
            }
        } else if zone.parentZone == nil {
            let index = indexOfMode(storageMode) // index is a KLUDGE

            storageMode = .bookmarks // going out arrow to left

            travel {
                var zone = self.hereZone

                if index < (zone?.children.count)! {
                    zone =  zone?.children[index]
                }

                atArrival(zone, .data)
            }
        }
    }
}
