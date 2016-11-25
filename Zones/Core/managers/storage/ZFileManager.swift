//
//  ZFileManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CoreFoundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZFileManager: NSObject {


    var isSaving: Bool = false


    // MARK:- API
    // MARK:-


    func save() {
        if !isSaving && operationsManager.isReady {
            isSaving               = true
            let dict: NSDictionary = travelManager.storageZone.storageDict as NSDictionary
            let  url:          URL = pathToCurrentZoneFile()

            dict.write(to: url, atomically: false)

            isSaving               = false
        }
    }


    func restore() {
        cloudManager.records.removeAll()
        
        if let raw = NSDictionary(contentsOf: pathToCurrentZoneFile()) {
            travelManager.storageZone = Zone(dict: raw as! ZStorageDict)
            travelManager.rootZone    = travelManager.storageZone
        }
    }


    // MARK:- internals
    // MARK:-


    let key: String = "current storage mode"


    var currentStorageMode: ZStorageMode {
        set { UserDefaults.standard.set(Int(newValue.rawValue), forKey:key) }
        get {
            var mode: ZStorageMode? = UserDefaults.standard.value(forKey:key) as? ZStorageMode

            if mode == nil {
                mode = .everyone

                UserDefaults.standard.set(Int((mode?.rawValue)!), forKey:key)
            }

            return mode!
        }
    }

    var currentZoneFileName: String {
        get {
            switch (travelManager.storageMode) {
            case .bookmarks: return "bookmarks.storage"
            case .everyone:  return "everyone.storage"
            case .group:     return "group.storage"
            case .mine:      return "mine.storage"
            }
        }
    }

    func pathToCurrentZoneFile() -> URL {
        return pathForZoneNamed(currentZoneFileName)
    }


    func pathForZoneNamed(_ iName: String) -> URL {
        return createFolderNamed("zones/\(iName)");
    }


    func createFolderNamed(_ iName: String) -> URL {
        let folder = Bundle.main.resourceURL!
        let    url = folder.appendingPathComponent(iName, isDirectory: false).standardizedFileURL
        let   path = url.deletingLastPathComponent().path;

        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }

        return url;
    }
}
