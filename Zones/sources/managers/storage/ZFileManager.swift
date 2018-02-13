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


    func write(for databaseID: ZDatabaseID?) {
        if  let        dbID = databaseID,
            let       index = indexOf(dbID), !isSaving[index],
            let        root = gRemoteStoresManager.rootZone(for: dbID),
            dbID           != .favoritesID,
            gSaveMode      != .cloudOnly {
            isSaving[index] = true // prevent rewrite
            var        dict = ZStorageDict ()

            if  let        graph  = root.storageDictionary(for: dbID)  { // snapshot of graph's root as of just before exit from method, down class from our smart dictionary
                dict     [.graph] = graph as NSObject
            }

            if  dbID             == .mineID,
                let    favorites  = gFavoritesManager.rootZone?.storageDictionary(for: dbID) {
                dict [.favorites] = favorites as NSObject
            }

            if  let    bookmarks  = gBookmarksManager.storageArray(for: dbID) {
                dict [.bookmarks] = bookmarks as NSObject
            }

            BACKGROUND {
                let jsonDict = self.jsonDictFrom(dict)
                let     path = self.fileURL(for: dbID).path
                let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

                if  FileManager.default.createFile(atPath: path, contents: data) {}

                self.isSaving[index] = false // end prevention of rewrite of file
            }
        }
    }


    func read(for databaseID: ZDatabaseID) {
        if  gFetchMode               != .cloudOnly &&
            databaseID               != .favoritesID {
            let                  path = fileURL(for: databaseID).path
            let types: [ZStorageType] = [.graph, .favorites, .bookmarks]
            do {
                if  let     data = FileManager.default.contents(atPath: path),
                    let     json = try JSONSerialization.jsonObject(with: data) as? [String : NSObject] {
                    let     dict = dictFromJSON(json)

                    for type in types {
                        if  let                 value = dict[type] {
                            if  let           subDict = value as? ZStorageDict {
                                let              root = Zone(dict: subDict, in: databaseID)
                                let dbID: ZDatabaseID = type == .favorites ? .favoritesID : databaseID

                                gRemoteStoresManager.setRootZone(root, for: dbID)
                                signalFor(nil, regarding: .redraw)
                            } else if let       array = value as? [ZStorageDict] {
                                for subDict in array {
                                    let      bookmark = Zone(dict: subDict, in: databaseID)

                                    gBookmarksManager.registerBookmark(bookmark)
                                }
                            }
                        }
                    }
                }
            } catch {
                print(error)    // de-serialization
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

            if !manager.fileExists(atPath: url.path) {
                manager.createFile(atPath: url.path, contents: nil)
            }
        } catch {
            print(error)
        }

        return url;
    }


    func fileURL(for databaseID: ZDatabaseID) -> URL { return fileURLForZoneNamed(fileName(for: databaseID)) }
    func fileURLForZoneNamed(_ iName: String) -> URL { return createFileNamed("graphs/\(iName)"); }


    func fileName(for databaseID: ZDatabaseID) -> String {
        var name = databaseID.rawValue

        name.append(".graph")

        return name
    }


    func dictFromJSON(_ dict: [String : NSObject]) -> ZStorageDict {
        var                  result = ZStorageDict ()

        for (key, value) in dict {
            if  let      storageKey = ZStorageType(rawValue: key) {
                var       goodValue = value

                if  let     subDict = value as? [String : NSObject] {
                    goodValue       = dictFromJSON(subDict) as NSObject
                } else if let array = value as? [[String : NSObject]] {
                    var   goodArray = [ZStorageDict] ()

                    for subDict in array {
                        goodArray.append(dictFromJSON(subDict))
                    }

                    goodValue       = goodArray as NSObject
                }

                result[storageKey]  = goodValue
            }
        }

        return result
    }


    func jsonDictFrom(_ dict: ZStorageDict) -> [String : NSObject] {
        var deferals = ZStorageDict ()
        var   result = [String : NSObject] ()

        let closure = { (key: ZStorageType, value: NSObject) in
            var goodValue = value
            let stringKey = key.rawValue

            if  let   subDict = value as? ZStorageDict {
                goodValue     = self.jsonDictFrom(subDict) as NSObject
            } else if let dictArray = value as? [ZStorageDict] {
                var goodArray = [[String : NSObject]] ()

                for subDict in dictArray {
                    goodArray.append(self.jsonDictFrom(subDict))
                }

                goodValue     = goodArray as NSObject
            }

            result[stringKey] = goodValue
        }

        for (key, value) in dict {
            if [.children, .traits].contains(key) {
                deferals[key] = value
            } else {
                closure(key, value)
            }
        }

        for (key, value) in deferals {
            closure(key, value)
        }

        return result
    }

}
