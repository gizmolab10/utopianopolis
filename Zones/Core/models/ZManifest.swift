//
//  ZManifest.swift
//  Zones
//
//  Created by Jonathan Sand on 12/3/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZManifest: ZRecord {


    dynamic var bookmarks: [CKReference] = []
    dynamic var  here:      CKReference?
    var         _hereZone:         Zone?


    var hereZone: Zone? {
        get {
            if _hereZone == nil {
                _hereZone = Zone(record: nil, storageMode: travelManager.storageMode)
            }

            return _hereZone
        }

        set {
            if  _hereZone != newValue {
                _hereZone  = newValue

                if let record = _hereZone?.record {
                    here = CKReference(record: record, action: .none)

                    needSave()
                }
            }
        }
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(here), #keyPath(bookmarks)]
    }
}
