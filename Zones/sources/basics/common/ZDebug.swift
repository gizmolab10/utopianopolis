//
//  ZDebug.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

// async: start from zfiles read: create managed object zone
//     storage dict create managed object zone and trait
//     create zone, trait ONLY if from dict
// NOT async: create bookmarks

var          gPrintModes : ZPrintMode    = [] // [.dSpeed]
var          gDebugModes : ZDebugMode    = [] // [.dDebugDraw]
var        gCoreDataMode : ZCoreDataMode = []

var     gIsUsingCoreData : Bool { return !gCoreDataMode.contains(.dDisabled) }
var             gCanSave : Bool { return !gCoreDataMode.contains(.dNotSave)  && gIsUsingCoreData }
var             gCanLoad : Bool { return !gCoreDataMode.contains(.dNotLoad)  && gIsUsingCoreData }
var     gIsUsingCloudKit : Bool { return  gCoreDataMode.contains(.dCloudKit) && gIsUsingCoreData }

var gSubscriptionTimeout : Bool { return  gDebugModes.contains(.dSubscriptionTimeout) }
var gIsShowingDuplicates : Bool { return  gDebugModes.contains(.dShowDuplicates) }
var     gIgnoreExemption : Bool { return  gDebugModes.contains(.dIgnoreExemption) }
var         gDebugAccess : Bool { return  gDebugModes.contains(.dDebugAccess) }
var          gAddDestroy : Bool { return  gDebugModes.contains(.dShowDestroy) }
var          gWriteFiles : Bool { return  gDebugModes.contains(.dWriteFiles) }
var           gDebugInfo : Bool { return  gDebugModes.contains(.dDebugInfo) }
var           gDebugDraw : Bool { return  gDebugModes.contains(.dDebugDraw) }
var           gReadFiles : Bool { return  gDebugModes.contains(.dReadFiles) }
var             gNewUser : Bool { return  gDebugModes.contains(.dNewUser) }

func gToggleDebugMode(_ mode: ZDebugMode) {
	if  gDebugModes.contains(mode) {
		gDebugModes  .remove(mode)
	} else {
		gDebugModes  .insert(mode)
	}
}

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

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let dNewUser             = ZDebugMode() // exercise new-user, first-time arrival code
	static let dReadFiles           = ZDebugMode() // read files
	static let dDebugInfo           = ZDebugMode() // inject debugging information into UI
	static let dDebugDraw           = ZDebugMode() // colorize rects
	static let dWriteFiles          = ZDebugMode() // write files
	static let dDebugAccess         = ZDebugMode() // test write access by me not having full
	static let dShowDestroy         = ZDebugMode() // add destroy bookmark to favorites
	static let dShowDuplicates      = ZDebugMode() // report duplicates
	static let dIgnoreExemption     = ZDebugMode() // ignore user exemption
	static let dSubscriptionTimeout = ZDebugMode() // super short timeout

	var description: String {
		return [(.dNewUser,             "arrival"),
				(.dReadFiles,           "read files"),
				(.dDebugInfo,           "show debug info"),
				(.dDebugDraw,           "debug draw"),
				(.dWriteFiles,          "write files"),
				(.dDebugAccess,         "debug write access"),
				(.dShowDestroy,         "add destroy bookmark"),
				(.dShowDuplicates,      "indicate zones with duplicates"),
				(.dIgnoreExemption,     "ignore user exemption"),
				(.dSubscriptionTimeout, "ignore subscription duration")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: kSpace)
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
	static let  dClick = ZPrintMode() // mouse click
	static let  dSpeed = ZPrintMode() // "
	static let  dNames = ZPrintMode() // decorate idea text with record names
	static let  dFocus = ZPrintMode() // push, /, bookmarks
	static let  dError = ZPrintMode() // error handling
	static let  dAdopt = ZPrintMode() // orphans
	static let  dCloud = ZPrintMode() // cloud read
	static let  dFetch = ZPrintMode() // children
	static let  dCross = ZPrintMode() // core data cross store relationships
	static let  dNotes = ZPrintMode() // essays
	static let  dExist = ZPrintMode() // core data existence check
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
				(.dCloud,  "  cloud"),
				(.dCross,  "  cross"),
				(.dClick,  "  click"),
				(.dExist,  "  exist"),
				(.dFetch,  "fetched"),
				(.dAccess, " access"),
				(.dWidget, " widget"),
				(.dRemote, " remote"),
				(.dImages, " images"),
				(.dTimers, " timers"),
				(.dLevels, " levels")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: kSpace)
	}

	static func toggle(_ mode: ZPrintMode) {
		if  gPrintModes.contains(mode) {
			gPrintModes  .remove(mode)
		} else {
			gPrintModes  .insert(mode)
		}
	}

}

extension ZMainController {

	@IBAction func debugInfoButtonAction(_ button: NSButton) {
		gToggleDebugMode(.dDebugInfo)
		gSignal([.spDebug, .spMain])
	}

}
