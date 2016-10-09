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
        let dict: NSDictionary = modelManager.selectedZone.storageDict as NSDictionary
        let  url:          URL = URL(fileURLWithPath: pathToCurrentZoneFile())

        dict.write(to:url, atomically: false)
    }


    func restore() {
        let url: URL = URL(fileURLWithPath: pathToCurrentZoneFile())
        let     dict = NSDictionary(contentsOf: url)

        if dict != nil {
            modelManager.selectedZone.storageDict = dict as! [String : NSObject]
        }
    }


    // MARK:- internals
    // MARK:-


    func pathForZoneNamed(_ iName: String) -> (String) {
        return createFolderNamed("zones/\(iName)");
    }


    func pathToCurrentZoneFile() -> (String) {
        return pathForZoneNamed(modelManager.selectedZone.zoneName!);
    }


    func createFolderNamed(_ iName: String) -> (String) {
        let  paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, false)
        let folder = paths[0]; // Get documents folder
        let   path = "\(folder)/\(iName)";

        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            } catch {}
        }

        return path;
    }
}
