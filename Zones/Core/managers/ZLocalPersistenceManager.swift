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


let persistenceManager = ZLocalPersistenceManager()


class ZLocalPersistenceManager: NSObject {


    // MARK:- API
    // MARK:-


    func save() {
        currentZoneFileName    = modelManager.selectedZone.record.recordID.recordName
        let dict: NSDictionary = modelManager.selectedZone.storageDict as NSDictionary
        let  url:          URL = pathToCurrentZoneFile()

        dict.write(to: url, atomically: true)
    }


    func restore() {
        let url: URL = pathToCurrentZoneFile()
        let      raw = NSDictionary(contentsOf: url)

        if raw != nil {
            let                              dict = raw as! [String : NSObject]
            modelManager.selectedZone.storageDict = dict
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
                name = "root"

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
        let  paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, false)
        let folder = URL(fileURLWithPath:paths[0], isDirectory:true).resolvingSymlinksInPath(); // Get documents folder
        let    url = folder.appendingPathComponent(iName, isDirectory: false)
        let   path = url.deletingLastPathComponent().absoluteString;

        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error)
            }
        }

        return url;
    }
}
