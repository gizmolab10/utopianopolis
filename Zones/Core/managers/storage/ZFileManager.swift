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


class ZFileManager: NSObject {


    var isSaving: Bool = false


    // MARK:- API
    // MARK:-


    func save(to storageMode: ZStorageMode?) {
        if !isSaving && gFileMode == .local && storageMode != nil && storageMode != .favorites && gOperationsManager.isReady {
            isSaving               = true
            let dict: NSDictionary = gRoot.storageDict as NSDictionary
            let  url:          URL = pathToFile(for: storageMode!)

            dict.write(to: url, atomically: false)

            isSaving               = false
        }
    }


    func restore(from storageMode: ZStorageMode) {
        gCloudManager.clear(storageMode)

        if gFileMode == .local && storageMode != .favorites {
            if let raw = NSDictionary(contentsOf: pathToFile(for: storageMode)) {
                gRoot = Zone(dict: raw as! ZStorageDict)
                gHere = gRoot

                signalFor(nil, regarding: .redraw)
            }
        }
    }
    

    // MARK:- internals
    // MARK:-


    func pathToFile(for storageMode: ZStorageMode) -> URL { return pathForZoneNamed(fileName(for: storageMode)) }
    func pathForZoneNamed(_ iName: String)         -> URL { return createFolderNamed("zones/\(iName)"); }


    func fileName(for storageMode: ZStorageMode) -> String {
        switch storageMode {
        case .favorites: return "favorites.storage"
        case .everyone:  return "everyone.storage"
        case .shared:    return "shared.storage"
        case .mine:      return "mine.storage"
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
