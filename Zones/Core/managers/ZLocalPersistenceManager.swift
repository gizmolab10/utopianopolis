//
//  ZLocalPersistenceManager.swift
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


class ZLocalPersistenceManager: NSObject {


    var isSaving: Bool = false


    // MARK:- API
    // MARK:-


    func save() {
        if !isSaving && stateManager.isReady {
            isSaving               = true
            currentZoneFileName    = "public"
            let dict: NSDictionary = zonesManager.rootZone.storageDict as NSDictionary
            let  url:          URL = pathToCurrentZoneFile()

            dict.write(to: url, atomically: false)

            isSaving               = false
        }
    }


    func restore() {
        if let raw = NSDictionary(contentsOf: pathToCurrentZoneFile()) {
            zonesManager.rootZone = Zone(dict: raw as! ZStorageDict)
        }
    }


    // MARK:- internals
    // MARK:-


    let key: String = "current zone file name"


    var currentZoneFileName: String {
        set { UserDefaults.standard.set(newValue, forKey:key) }
        get {
            var name: String? = UserDefaults.standard.value(forKey:key) as? String

            if name == nil {
                name = "public"

                UserDefaults.standard.set(name, forKey:key)
            }

            return name!
        }
    }


    func pathToCurrentZoneFile() -> URL {
        return pathForZoneNamed(currentZoneFileName);
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
