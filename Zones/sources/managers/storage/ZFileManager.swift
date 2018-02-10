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


    var isSaving = [false, false] // not allow another save while file is being written


    // MARK:- API
    // MARK:-


    func write(for databaseID: ZDatabaseiD?) {
        if  let        dbID = databaseID,
            let       index = indexOf(dbID), !isSaving[index],
            let        root = gRemoteStoresManager.rootZone(for: dbID),
            dbID           != .favoritesID,
            gSaveMode      != .cloudOnly {
            isSaving[index] = true // prevent rewrite
            let        dict = root.storageDict // snapshot of graph's root as of just before exit from method, down class from our smart dictionary

            BACKGROUND {
                let     path = self.pathToFile(for: dbID).path
                let jsonDict = self.jsonDictFrom(dict)
                do {
                    let data = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

                    if  FileManager.default.createFile(atPath: path, contents: data) {}
                } catch {
                    print(error)
                }

                self.isSaving[index] = false // end prevention of rewrite of file
            }
        }
    }


    func jsonDictFrom(_ dict: ZStorageDict) -> [String : NSObject] {
        var            result = [String : NSObject] ()

        for (key, value) in dict {
            var goodValue: NSObject = value
            let     stringKey = key.rawValue

            if  let dictArray = value as? [ZStorageDict] {
                var goodArray = [[String : NSObject]] ()

                for subDict in dictArray {
                    let  json = jsonDictFrom(subDict)

                    goodArray.append(json)
                }

                goodValue = goodArray as NSObject
            }

            result[stringKey] = goodValue
        }

        return result
    }


    func read(for databaseiD: ZDatabaseiD) {
        if  gFetchMode  != .cloudOnly &&
            databaseiD  != .favoritesID {
            if  let  raw = NSDictionary(contentsOfFile: pathToFile(for: databaseiD).path) {
                let root = Zone(dict: raw as! ZStorageDict) // broken, ignores database identifier
                gHere    = root

                gRemoteStoresManager.recordsManagerFor(databaseiD)?.rootZone = root

                signalFor(nil, regarding: .redraw)
            }
        }
    }
    

    // MARK:- internals
    // MARK:-


    func createFileNamed(_ iName: String) -> URL {
        let folder = try! FileManager().url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//      let folder = Bundle.main.resourceURL!
        let    url = folder.appendingPathComponent(iName, isDirectory: false).standardizedFileURL
        let   path = url.deletingLastPathComponent().path;

        do {
            let manager = FileManager.default

            try manager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)

            manager.createFile(atPath: url.path, contents: nil)
        } catch {
            print(error)
        }

        return url;
    }


    func pathToFile(for databaseiD: ZDatabaseiD) -> URL { return pathForZoneNamed(fileName(for: databaseiD)) }
    func pathForZoneNamed(_ iName: String)       -> URL { return createFileNamed("graphs/\(iName)"); }


    func fileName(for databaseiD: ZDatabaseiD) -> String {
        var name = databaseiD.rawValue

        name.append(".graph")

        return name
    }

}
