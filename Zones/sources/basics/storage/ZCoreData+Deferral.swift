//
//  ZCoreDataStack.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

extension ZCoreDataStack {

	// MARK: - existence closures
	// MARK: -

	func setClosures(_ closures: ZExistenceArray, for entityName: String, databaseID: ZDatabaseID) {
		var dict  = existenceClosures[databaseID]
		if  dict == nil {
			dict  = ZExistenceDictionary()
		}

		dict?      [entityName] = closures
		existenceClosures[databaseID] = dict!
	}

	func closures(for entityName: String, databaseID: ZDatabaseID) -> ZExistenceArray {
		var d  = existenceClosures[databaseID]
		var c  = d?[entityName]
		if  d == nil {
			d  = ZExistenceDictionary()
		}

		if  c == nil {
			c  = ZExistenceArray()
			d?[entityName] = c!
		}

		existenceClosures[databaseID] = d!

		return c!
	}

	func processClosures(for  entityName: String, databaseID: ZDatabaseID, _ onCompletion: IntClosure?) {
		var array = closures(for: entityName, databaseID: databaseID)

		if  array.count == 0 {
			onCompletion?(0)
		} else if let       c = context {
			let         count = "\(array.count)".appendingSpacesToLength(6)
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = array.predicate(entityName)

			printDebug(.dExist, "\(databaseID.identifier) = \(count)\(entityName)")

			deferUntilAvailable(for: .oExistence) {
				FOREBACKGROUND { [self] in
					do {
						let items = try c.fetch(request)

						FOREGROUND { [self] in
							for item in items {
								if  let zRecord = item as? ZRecord {           // insert zrecord into closures
									array.updateClosureForZRecord(zRecord, of: entityName)
									zRecord.needAdoption()
								}
							}

							array.fireClosures()
							setClosures([], for: entityName, databaseID: databaseID)
							makeAvailable()
							onCompletion?(0)
						}
					} catch {
						printDebug(.dError, "\(error)")
					}
				}
			}
		}
	}

	func finishCreating(for databaseID: ZDatabaseID, _ onCompletion: IntClosure?) {
		guard let dict = existenceClosures[databaseID] else {
			onCompletion?(0) // so next operation can begin

			return
		}

		let entityNames = dict.map { $0.key }
		let  firstIndex = entityNames.count - 1

		func processForEntityName(at index: Int) {
			if  index < 0 {
				onCompletion?(0)                                       // exit recursive loop and let next operation begin
			} else {
				let entityName = entityNames[index]

				processClosures(for: entityName, databaseID: databaseID) { value in
					processForEntityName(at: index - 1)                // recursive while loop
				}
			}
		}

		processForEntityName(at: firstIndex)
	}

	// MARK: - core data prefers one operation at a time
	// MARK: -

	func isAvailable(for opID: ZCDOperationID) -> Bool { return currentOpID == nil || currentOpID == opID }
	func makeAvailable()                               {        currentOpID  = nil }

	func invokeDeferralMaybe(_ iTimerID: ZTimerID?) {
		if  currentOpID == nil {                  // nil means core data is no longer doing anything
			if  deferralStack.count == 0 {        // check if anything is deferred
				gTimers.stopTimer(for: iTimerID)  // do not fire again, closure is no longer invoked
			} else {
				let waiting = deferralStack.remove(at: 0)
				currentOpID = waiting.opID

				gSignal([.spDataDetails])         // tell data detail view about it
				waiting.closure?()                // do what was deferred
			}
		}
	}

	func deferUntilAvailable(for opID: ZCDOperationID, _ onAvailable: @escaping Closure) {
		if  currentOpID == nil {
			currentOpID  = opID

			onAvailable()
		} else {
			for deferred in deferralStack {
				if  deferred.opID == opID {
					return // this op is already deferred
				}
			}

			deferralStack.append(ZDeferral(closure: onAvailable, opID: opID))

			gTimers.startTimer(for: .tCoreDataDeferral)
		}
	}
}

struct ZDeferral {
	let closure : Closure?         // for deferralHappensMaybe to invoke
	let    opID : ZCDOperationID   // so status text can show it
}

struct ZEntityDescriptor {
	let entityName : String
	let recordName : String?
	let databaseID : ZDatabaseID
}

struct ZExistence {
	var zRecord : ZRecord?
	var closure : ZRecordClosure?
	let  entity : ZEntityDescriptor?
	let    file : ZFileDescriptor?
}

enum ZCDOperationID: Int {
	case oLoad
	case oSave
	case oFetch
	case oSearch
	case oAssets
	case oProgeny
	case oExistence

	var description : String {
		var string = "\(self)".lowercased().substring(fromInclusive: 1)

		switch self {
			case .oProgeny:   return   "loading " + string
			case .oExistence: string = "checking exist"
			case .oSave:      string = "sav"
			default:          break
		}

		return string + "ing local data"
	}
}

typealias ZExistenceArray      =        [ZExistence]
typealias ZExistenceDictionary = [String:ZExistenceArray]

extension ZExistenceArray {

	func fireClosures() {
		var counter = [ZDatabaseID : Int]()

		func count(_    r : ZRecord) {
			if  let    id = r.maybeDatabaseID{
				if  let x = counter[id] {
					counter[id] = x + 1
				} else {
					counter[id] = 1
				}
			}
		}

		for e in self {
			if  let close = e.closure,
				let     r = e.zRecord {

				count(r)
				close(r)   // invoke closure
			}
		}

		for (i, x) in counter {
			printDebug(.dExist, "\(i.identifier) ! \(x)")
		}
	}

	mutating func updateClosureForZRecord(_ zRecord: ZRecord, of type: String) {
		let name = (type == kFileType) ? (zRecord as? ZFile)?.name : (zRecord.recordName)

		for (index, e) in enumerated() {
			var ee = e

			if  name == e.file?.name || name == e.entity?.recordName {
				ee.zRecord  = zRecord
				self[index] = ee
			}
		}
	}

	func predicate(_ type: String) -> NSPredicate {
		let    isFile = type == kFileType
		let   keyPath = isFile ? "name" : "recordName"
		var     items = kEmpty
		var separator = kEmpty

		for e in self {
			if  isFile {
				if  let  file = e.file,
					let  name = file.name {
					items.append("\(separator)'\(name)'")
					separator = kCommaSeparator
				}
			} else {
				if  let entity = e.entity,
					let   name = entity.recordName {
					items.append("\(separator)'\(name)'")
					separator  = kCommaSeparator
				}
			}
		}

		let format = "\(keyPath) in { \(items) }"

		return NSPredicate(format: format)
	}
}
