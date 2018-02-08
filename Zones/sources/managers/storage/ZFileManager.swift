//
//  ZFileManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CoreFoundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


let gFileManager = ZFileManager()


class ZFileManager: NSObject {


    var isSaving: Bool = false


    // MARK:- API
    // MARK:-


    func save(to databaseiD: ZDatabaseiD?) {
        if !isSaving &&
            gFetchMode             != .cloudOnly &&
            databaseiD             != nil &&
            databaseiD             != .favoritesID {
            isSaving                = true
            let                root = gRemoteStoresManager.rootZone(for: databaseiD!)
            let dict:  NSDictionary = root!.storageDict as NSDictionary
            let  url:           URL = pathToFile(for: databaseiD!)

            dict.write(to: url, atomically: false)

            isSaving               = false
        }
    }


    func restore(from databaseiD: ZDatabaseiD) {
        if  gStoreMode  != .cloudOnly &&
            databaseiD  != .favoritesID {
            if  let  raw = NSDictionary(contentsOf: pathToFile(for: databaseiD)) {
                let root = Zone(dict: raw as! ZStorageDict) // broken, ignores database identifier
                gHere    = root

                gRemoteStoresManager.recordsManagerFor(databaseiD)?.rootZone = root

                signalFor(nil, regarding: .redraw)
            }
        }
    }
    

    // MARK:- internals
    // MARK:-


    func pathToFile(for databaseiD: ZDatabaseiD) -> URL { return pathForZoneNamed(fileName(for: databaseiD)) }
    func pathForZoneNamed(_ iName: String)       -> URL { return createFolderNamed("zones/\(iName)"); }


    func fileName(for databaseiD: ZDatabaseiD) -> String {
        switch databaseiD {
        case .favoritesID: return "favorites.storage"
        case  .everyoneID: return "everyone.storage"
        case    .sharedID: return "shared.storage"
        case      .mineID: return "mine.storage"
        }
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
