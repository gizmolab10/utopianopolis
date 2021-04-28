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

	var lookup = [ZDatabaseID : ZDoubleLookup]()

	func register(_ file: ZFile, in dbID: ZDatabaseID?) {
		if  let      dbid = dbID,
			let      type = file.type,
			let      name = file.name {
			var      dict = lookup[dbid] ?? ZDoubleLookup()
			var   subdict = dict  [type] ?? ZSingleLookup()
			subdict[name] = file
			dict   [type] = subdict
			lookup [dbid] = dict
		}
	}

	func assetExists(named: String, type: String, in dbID: ZDatabaseID?, onCompletion: ZRecordClosure? = nil) {
		var file: ZRecord?

		if  let    dbid = dbID,
			let    dict = lookup [dbid],
			let subdict = dict   [type] {
			file        = subdict[named]
		}

		onCompletion?(file)
	}
}
