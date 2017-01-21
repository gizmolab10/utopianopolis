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
        if !isSaving && gFileMode == .local && gStorageMode != .favorites && operationsManager.isReady {
            isSaving               = true
            let dict: NSDictionary = travelManager.rootZone!.storageDict as NSDictionary
            let  url:          URL = pathToCurrentZoneFile()

            dict.write(to: url, atomically: false)

            isSaving               = false
        }
    }


    func restore() {
        cloudManager.clear()

        if gFileMode == .local && gStorageMode != .favorites {
            if let raw = NSDictionary(contentsOf: pathToCurrentZoneFile()) {
                travelManager.rootZone = Zone(dict: raw as! ZStorageDict)
                travelManager.hereZone = travelManager.rootZone

                signalFor(nil, regarding: .redraw)
            }
        }
    }
    

    // MARK:- internals
    // MARK:-


    var currentZoneFileName: String {
        get {
            switch gStorageMode {
            case .favorites: return "favorites.storage"
            case .everyone:  return "everyone.storage"
            case .shared:    return "shared.storage"
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
