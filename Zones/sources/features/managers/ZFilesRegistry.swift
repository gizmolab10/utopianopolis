//
//  ZFilesRegistry.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gFilesRegistry = ZFilesRegistry()

typealias ZSingleLookup = [String : ZFile]
typealias ZDoubleLookup = [String : ZSingleLookup]

class ZFilesRegistry {

	var       lookup = [ZDatabaseID : ZDoubleLookup]()
	var byRecordName = [ZDatabaseID : ZSingleLookup]()

	func register(_ file: ZFile, in dbID: ZDatabaseID) {
		if  let           type = file.type,
			let           name = file.name,
			let          rName = file.recordName {
			var          rDict = byRecordName[dbID] ?? ZSingleLookup()
			var          lDict = lookup      [dbID] ?? ZDoubleLookup()
			var        subdict = lDict       [type] ?? ZSingleLookup()
			subdict     [name] = file
			rDict      [rName] = file
			lDict       [type] = subdict
			lookup      [dbID] = lDict
			byRecordName[dbID] = rDict
		}
	}

	func fileWith(_ recordName: String, in dbID: ZDatabaseID) -> ZFile? {
		return byRecordName[dbID]?[recordName]
	}

	func assetExists(for descriptor: ZFileDescriptor?) -> ZFile? {
		var file: ZRecord?

		if  let    dbid = descriptor?.dbID,
			let    name = descriptor?.name,
			let    type = descriptor?.type,
			let    dict = lookup [dbid],
			let subdict = dict   [type] {
			file        = subdict[name]
		}

		return file as? ZFile
	}
}
