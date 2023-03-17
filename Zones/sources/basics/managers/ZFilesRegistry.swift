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

	func register(_ file: ZFile, in databaseID: ZDatabaseID) {
		if  let           type = file.type,
			let           name = file.name,
			let          rName = file.recordName {
			var          rDict = byRecordName[databaseID] ?? ZSingleLookup()
			var          lDict = lookup      [databaseID] ?? ZDoubleLookup()
			var        subdict = lDict       [type] ?? ZSingleLookup()
			subdict     [name] = file
			rDict      [rName] = file
			lDict       [type] = subdict
			lookup      [databaseID] = lDict
			byRecordName[databaseID] = rDict
		}
	}

	func fileWith(_ recordName: String, in databaseID: ZDatabaseID) -> ZFile? {
		return byRecordName[databaseID]?[recordName]
	}

	func assetExists(for descriptor: ZFileDescriptor?) -> ZFile? {
		var file: ZRecord?

		if  let    dbid = descriptor?.databaseID,
			let    name = descriptor?.name,
			let    type = descriptor?.type,
			let    dict = lookup [dbid],
			let subdict = dict   [type] {
			file        = subdict[name]
		}

		return file as? ZFile
	}
}
