//
//  ZDebug.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var     gIsUsingCoreData : Bool { return !gCoreDataMode.contains(.dDisabled) }
var             gCanSave : Bool { return !gCoreDataMode.contains(.dNotSave)  && gIsUsingCoreData }
var             gCanLoad : Bool { return !gCoreDataMode.contains(.dNotLoad)  && gIsUsingCoreData }
var     gIsUsingCloudKit : Bool { return  gCoreDataMode.contains(.dCloudKit) && gIsUsingCoreData }

var gSubscriptionTimeout : Bool { return  gDebugModes.contains(.dSubscriptionTimeout) }
var gIsShowingDuplicates : Bool { return  gDebugModes.contains(.dShowDuplicates) }
var     gIgnoreExemption : Bool { return  gDebugModes.contains(.dIgnoreExemption) }
var         gDebugAngles : Bool { return  gDebugModes.contains(.dDebugAngles) }
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
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let dDisabled = ZCoreDataMode(rawValue: 2 ^ 0) // cannot use core data
	static let dCloudKit = ZCoreDataMode(rawValue: 2 ^ 1) // store in cloud kit
	static let dNotSave  = ZCoreDataMode(rawValue: 2 ^ 2) // save is not operational
	static let dNotLoad  = ZCoreDataMode(rawValue: 2 ^ 3) // load is not operational
}

struct ZDebugMode: OptionSet, CustomStringConvertible {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let dNone                = ZDebugMode(rawValue: 2 ^  0)
	static let dNewUser             = ZDebugMode(rawValue: 2 ^  1) // exercise new-user, first-time arrival code
	static let dReadFiles           = ZDebugMode(rawValue: 2 ^  2) // read files
	static let dDebugInfo           = ZDebugMode(rawValue: 2 ^  3) // inject debugging information into UI
	static let dDebugDraw           = ZDebugMode(rawValue: 2 ^  4) // colorize rects
	static let dWriteFiles          = ZDebugMode(rawValue: 2 ^  5) // write files
	static let dDebugAngles         = ZDebugMode(rawValue: 2 ^  6) // experiment with circular angle algorithm
	static let dDebugAccess         = ZDebugMode(rawValue: 2 ^  7) // test write access by me not having full
	static let dShowDestroy         = ZDebugMode(rawValue: 2 ^  8) // add destroy bookmark to favorites
	static let dShowDuplicates      = ZDebugMode(rawValue: 2 ^  9) // report duplicates
	static let dIgnoreExemption     = ZDebugMode(rawValue: 2 ^ 10) // ignore user exemption
	static let dSubscriptionTimeout = ZDebugMode(rawValue: 2 ^ 11) // super short timeout

	var description: String { return descriptions.joined(separator: kSpace) }

	var descriptions: [String] {
		return [(.dNewUser,             "arrival"),
				(.dReadFiles,           "read files"),
				(.dDebugInfo,           "show debug info"),
				(.dDebugDraw,           "debug draw"),
				(.dWriteFiles,          "write files"),
				(.dDebugAngles,         "debug circular angle algorithm"),
				(.dDebugAccess,         "debug write access"),
				(.dShowDestroy,         "add destroy bookmark"),
				(.dShowDuplicates,      "indicate zones with duplicates"),
				(.dIgnoreExemption,     "ignore user exemption"),
				(.dSubscriptionTimeout, "ignore subscription duration")]
			.compactMap { (option, name) in contains(option) ? name : nil }
	}
}

struct ZPrintMode: OptionSet, CustomStringConvertible {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let   dNone = ZPrintMode(rawValue: 2 ^  0)
	static let    dOps = ZPrintMode(rawValue: 2 ^  1) // operations
	static let    dFix = ZPrintMode(rawValue: 2 ^  2) // disappearing ideas
	static let    dLog = ZPrintMode(rawValue: 2 ^  3) // miscellaneous
	static let   dEdit = ZPrintMode(rawValue: 2 ^  4) // become first responder funny business
	static let   dFile = ZPrintMode(rawValue: 2 ^  5) // parsing, error handling
	static let   dUser = ZPrintMode(rawValue: 2 ^  6) // user interruption of busy loops
	static let   dTime = ZPrintMode(rawValue: 2 ^  7) // stopwatch
	static let   dData = ZPrintMode(rawValue: 2 ^  8) // core data
	static let  dClick = ZPrintMode(rawValue: 2 ^  9) // mouse click
	static let  dSpeed = ZPrintMode(rawValue: 2 ^ 10) // "
	static let  dNames = ZPrintMode(rawValue: 2 ^ 11) // decorate idea text with record names
	static let  dFocus = ZPrintMode(rawValue: 2 ^ 12) // push, /, bookmarks
	static let  dError = ZPrintMode(rawValue: 2 ^ 13) // error handling
	static let  dAdopt = ZPrintMode(rawValue: 2 ^ 14) // orphans
	static let  dCloud = ZPrintMode(rawValue: 2 ^ 15) // cloud read
	static let  dFetch = ZPrintMode(rawValue: 2 ^ 16) // children
	static let  dCross = ZPrintMode(rawValue: 2 ^ 17) // core data cross store relationships
	static let  dNotes = ZPrintMode(rawValue: 2 ^ 18) // essays
	static let  dExist = ZPrintMode(rawValue: 2 ^ 19) // core data existence check
	static let dImages = ZPrintMode(rawValue: 2 ^ 20) // "
	static let dAccess = ZPrintMode(rawValue: 2 ^ 21) // write lock
	static let dRemote = ZPrintMode(rawValue: 2 ^ 22) // arrival from cloud
	static let dWidget = ZPrintMode(rawValue: 2 ^ 23) // lookup, hit tests
	static let dTimers = ZPrintMode(rawValue: 2 ^ 24) // assure completion
	static let dLevels = ZPrintMode(rawValue: 2 ^ 25) // fetching depth

	var description: String { return descriptions.joined(separator: kSpace) }

	var descriptions: [String] {
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

	@IBAction func debugInfoButtonAction(_ button: ZButton) {
		gToggleDebugMode(.dDebugInfo)
		gSignal([.spDebug, .spMain])
	}

}
