//
//  ZDebug.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

var   gDebugModes : ZDebugMode    = []
var   gPrintModes : ZPrintMode    = []
var gCoreDataMode : ZCoreDataMode = []
var  gUseCoreData : Bool { return !gCoreDataMode.contains(.dDisabled) }
var      gCanSave : Bool { return !gCoreDataMode.contains(.dNotSave)  && gUseCoreData }
var      gCanLoad : Bool { return !gCoreDataMode.contains(.dNotLoad)  && gUseCoreData }
var  gUseCloudKit : Bool { return  gCoreDataMode.contains(.dCloudKit) && gUseCoreData }
var  gDebugAccess : Bool { return  gDebugModes.contains(.dDebugAccess) }
var   gWriteFiles : Bool { return  gDebugModes.contains(.dWriteFiles) }
var    gDebugInfo : Bool { return  gDebugModes.contains(.dDebugInfo) }
var    gDebugDraw : Bool { return  gDebugModes.contains(.dDebugDraw) }
var    gReadFiles : Bool { return  gDebugModes.contains(.dReadFiles) }
var      gNewUser : Bool { return  gDebugModes.contains(.dNewUser) }

struct ZCoreDataMode: OptionSet {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZCoreDataMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let dDisabled = ZCoreDataMode() // cannot use core data
	static let dCloudKit = ZCoreDataMode() // store in cloud kit
	static let dNotSave  = ZCoreDataMode() // save is not operational
	static let dNotLoad  = ZCoreDataMode() // load is not operational
}

enum ZCDOperationID: Int {
	case oLoad
	case oSave
	case oSearch
	case oProgeny

	var description : String {
		var string = "\(self)".lowercased().substring(fromInclusive: 1)

		switch self {
			case .oProgeny: return "loading " + string
			case .oSave:    string = "sav"
			default:        break
		}

		return string + "ing local data"
	}
}

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let dNewUser     = ZDebugMode() // exercise new-user, first-time arrival code
	static let dReadFiles   = ZDebugMode() // read files
	static let dDebugInfo   = ZDebugMode() // inject debugging information into UI
	static let dDebugDraw   = ZDebugMode() // colorize rects
	static let dWriteFiles  = ZDebugMode() // write files
	static let dDebugAccess = ZDebugMode() // test write access by me not having full

	var description: String {
		return [(.dDebugAccess, "access"),
				(.dNewUser,     "arrival"),
				(.dReadFiles,   "read files"),
				(.dDebugInfo,   "show debug info"),
				(.dDebugDraw,   "debug draw"),
				(.dWriteFiles,  "write files"),
				(.dDebugAccess, "debug write access")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}
}

struct ZPrintMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZPrintMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let   dNone = ZPrintMode()
	static let    dOps = ZPrintMode() // operations
	static let    dFix = ZPrintMode() // disappearing ideas
	static let    dLog = ZPrintMode() // miscellaneous
	static let   dEdit = ZPrintMode() // become first responder funny business
	static let   dFile = ZPrintMode() // parsing, error handling
	static let   dUser = ZPrintMode() // user interruption of busy loops
	static let   dTime = ZPrintMode() // stopwatch
	static let   dData = ZPrintMode() // core data
	static let  dSpeed = ZPrintMode() // "
	static let  dNames = ZPrintMode() // decorate idea text with record names
	static let  dFocus = ZPrintMode() // push, /, bookmarks
	static let  dError = ZPrintMode() // error handling
	static let  dAdopt = ZPrintMode() // orphans
	static let  dFetch = ZPrintMode() // cloud read
	static let  dCount = ZPrintMode() // children
	static let  dCross = ZPrintMode() // core data cross store relationships
	static let  dNotes = ZPrintMode() // essays
	static let dImages = ZPrintMode() // "
	static let dAccess = ZPrintMode() // write lock
	static let dRemote = ZPrintMode() // arrival from cloud
	static let dWidget = ZPrintMode() // lookup, hit tests
	static let dTimers = ZPrintMode() // assure completion
	static let dLevels = ZPrintMode() // fetching depth

	var description: String {
		return [(.dOps,    "     op"),
				(.dFix,    "    fix"),
				(.dLog,    "    log"),
				(.dFile,   "   file"),
				(.dTime,   "   time"),
				(.dEdit,   "   edit"),
				(.dUser,   "   user"),
				(.dData,   "   data"),
				(.dNames,  "   name"),
				(.dNotes,  "   note"),
				(.dFocus,  "  focus"),
				(.dSpeed,  "  speed"),
				(.dError,  "  error"),
				(.dAdopt,  "  adopt"),
				(.dFetch,  "  fetch"),
				(.dCount,  "  count"),
				(.dCross,  "  cross"),
				(.dAccess, " access"),
				(.dWidget, " widget"),
				(.dRemote, " remote"),
				(.dImages, " images"),
				(.dTimers, " timers"),
				(.dLevels, " levels")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}

	static func toggle(_ mode: ZPrintMode) {
		if  gPrintModes.contains(mode) {
			gPrintModes  .remove(mode)
		} else {
			gPrintModes  .insert(mode)
		}
	}

}

