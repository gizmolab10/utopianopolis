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
        if !isSaving && stateManager.isReady {
            isSaving               = true
            let dict: NSDictionary = zonesManager.storageRootZone.storageDict as NSDictionary
            let  url:          URL = pathToCurrentZoneFile()

            dict.write(to: url, atomically: false)

            isSaving               = false
        }
    }


    func restore() {
        if let raw = NSDictionary(contentsOf: pathToCurrentZoneFile()) {
            zonesManager.storageRootZone = Zone(dict: raw as! ZStorageDict)
            zonesManager.rootZone        = zonesManager.storageRootZone
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
            switch (cloudManager.storageMode) {
            case .everyone: return "everyone.storage"
            case .mine:     return "mine.storage"
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
