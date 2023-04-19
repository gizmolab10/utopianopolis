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

func gSetupDebugFeatures() {

	// all these flags will eventually be commented out

	gDebugModes         = []
	gDebugModes  .insert(.dNoSubscriptions)
	gDebugModes  .insert(.dHideNoteVisibility)

	gCoreDataMode       = []
//	gCoreDataMode.insert(.dUseFlat)             // use flat data folder
	gCoreDataMode.insert(.dNotUseCloud)         // confusing, duplicate traits
	gCoreDataMode.insert(.dEraseStores)         // discard CD stores and start from stratch
//	gCoreDataMode.insert(.dNotUseUserID)        // not use <user id> in store file path
	gCoreDataMode.insert(.dNotTestTrashed)      // ignore isTrashed during fetch TODO: missing keypath
	gCoreDataMode.insert(.dNoRelationships)     // don't use the relationships table yet
//	gCoreDataMode.insert(.dInitializeCloud)     // do this once, when change and reset CK schema
	gCoreDataMode.insert(.dTestingMigration)    // store core data in a separate test folder

	gPrintModes         = []
//	gPrintModes  .insert(.dEdit)
//	gPrintModes  .insert(.dTime)
	gPrintModes  .insert(.dError)
	gPrintModes  .insert(.dCross)
//	gPrintModes  .insert(.dMoving)
//	gPrintModes  .insert(.dMigrate)

	if !gCDUseExistingStores {  // if we erase stores, we should also erase old record names
		gClearHereRecordNames()
	}
}

// all these are eventually going to be true

var           gIsUsingCD : Bool { return !gCoreDataMode.contains(.dDisabled) }
var           gCDCanSave : Bool { return !gCoreDataMode.contains(.dNotSave)          && gIsUsingCD }
var           gCDCanLoad : Bool { return !gCoreDataMode.contains(.dNotLoad)          && gIsUsingCD }
var          gCDUseCloud : Bool { return !gCoreDataMode.contains(.dNotUseCloud)      && gIsUsingCD }
var         gCDUseUserID : Bool { return !gCoreDataMode.contains(.dNotUseUserID)     && gIsUsingCD }
var       gCDNormalStore : Bool { return !gCoreDataMode.contains(.dTestingMigration) && gIsUsingCD }
var       gCDTestTrashed : Bool { return !gCoreDataMode.contains(.dNotTestTrashed)   && gIsUsingCD }
var      gCDUseHierarchy : Bool { return !gCoreDataMode.contains(.dUseFlat)          && gIsUsingCD }
var      gCDLoadEachRoot : Bool { return !gCoreDataMode.contains(.dLoadAllAtOnce)    && gIsUsingCD }
var     gCKIsInitialized : Bool { return !gCoreDataMode.contains(.dInitializeCloud)  && gIsUsingCD }
var  gCDUseRelationships : Bool { return !gCoreDataMode.contains(.dNoRelationships)  && gIsUsingCD }
var gCDUseExistingStores : Bool { return !gCoreDataMode.contains(.dEraseStores)      && gIsUsingCD }

var gIsShowingDuplicates : Bool { return  gDebugModes  .contains(.dShowDuplicates) }
var gSubscriptionTimeout : Bool { return  gDebugModes  .contains(.dSubscriptionTimeout) }
var  gHideNoteVisibility : Bool { return  gDebugModes  .contains(.dHideNoteVisibility) }
var     gNoSubscriptions : Bool { return  gDebugModes  .contains(.dNoSubscriptions) }
var     gIgnoreExemption : Bool { return  gDebugModes  .contains(.dIgnoreExemption) }
var         gDebugAngles : Bool { return  gDebugModes  .contains(.dDebugAngles) }
var         gDebugAccess : Bool { return  gDebugModes  .contains(.dDebugAccess) }
var          gAddDestroy : Bool { return  gDebugModes  .contains(.dShowDestroy) }
var          gWriteFiles : Bool { return  gDebugModes  .contains(.dWriteFiles) }
var           gDebugInfo : Bool { return  gDebugModes  .contains(.dDebugInfo) }
var           gDebugDraw : Bool { return  gDebugModes  .contains(.dDebugDraw) }
var             gNewUser : Bool { return  gDebugModes  .contains(.dNewUser) }

struct ZCoreDataMode: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let dNotSave          = ZCoreDataMode(rawValue: 1 << 00) // save is not operational
	static let dNotLoad          = ZCoreDataMode(rawValue: 1 << 01) // load is not operational
	static let dUseFlat          = ZCoreDataMode(rawValue: 1 << 02) // use flat data folder and not use <user id> in store file path
	static let dDisabled         = ZCoreDataMode(rawValue: 1 << 03) // cannot use core data
	static let dNotUseCloud      = ZCoreDataMode(rawValue: 1 << 04) // store in cloud kit
	static let dEraseStores      = ZCoreDataMode(rawValue: 1 << 05) // start the CD repo fresh
	static let dNotUseUserID     = ZCoreDataMode(rawValue: 1 << 06) // use flat data folder and not use <user id> in store file path
	static let dLoadAllAtOnce    = ZCoreDataMode(rawValue: 1 << 07) // load all zones and traits at once (only marginally faster, percentages don't show)
	static let dNotTestTrashed   = ZCoreDataMode(rawValue: 1 << 08) // ignore isTrashed during fetch
	static let dNoRelationships  = ZCoreDataMode(rawValue: 1 << 09) // not use ZRelationship
	static let dInitializeCloud  = ZCoreDataMode(rawValue: 1 << 10) // only need to do this once
	static let dTestingMigration = ZCoreDataMode(rawValue: 1 << 11) // use migration.testing (not data)
}

func gToggleDebugMode(_ mode: ZDebugMode) {
	if  gDebugModes.contains(mode) {
		gDebugModes  .remove(mode)
	} else {
		gDebugModes  .insert(mode)
	}
}

struct ZDebugMode: OptionSet, CustomStringConvertible {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let dNone                = ZDebugMode(rawValue: 1 <<  0)
	static let dNewUser             = ZDebugMode(rawValue: 1 <<  1) // exercise new-user, first-time arrival code
	static let dDebugInfo           = ZDebugMode(rawValue: 1 <<  2) // inject debugging information into UI
	static let dDebugDraw           = ZDebugMode(rawValue: 1 <<  3) // colorize rects
	static let dWriteFiles          = ZDebugMode(rawValue: 1 <<  4) // write files
	static let dDebugAngles         = ZDebugMode(rawValue: 1 <<  5) // experiment with circular angle algorithm
	static let dDebugAccess         = ZDebugMode(rawValue: 1 <<  6) // test write access by me not having full
	static let dShowDestroy         = ZDebugMode(rawValue: 1 <<  7) // add destroy bookmark to favorites
	static let dShowDuplicates      = ZDebugMode(rawValue: 1 <<  8) // report duplicates
	static let dIgnoreExemption     = ZDebugMode(rawValue: 1 <<  9) // ignore user exemption
	static let dNoSubscriptions     = ZDebugMode(rawValue: 1 << 10) // not incorporate subscriptions
	static let dHideNoteVisibility  = ZDebugMode(rawValue: 1 << 11) // note visibility icons
	static let dSubscriptionTimeout = ZDebugMode(rawValue: 1 << 12) // super short timeout

	var description: String { return descriptions.joined(separator: kSpace) }

	var descriptions: [String] {
		return [(.dNewUser,             "arrival"),
				(.dDebugInfo,           "show debug info"),
				(.dDebugDraw,           "debug draw"),
				(.dWriteFiles,          "write files"),
				(.dDebugAngles,         "debug circular angle algorithm"),
				(.dDebugAccess,         "debug write access"),
				(.dShowDestroy,         "add destroy bookmark"),
				(.dShowDuplicates,      "indicate zones with duplicates"),
				(.dIgnoreExemption,     "ignore user exemption"),
				(.dNoSubscriptions,     "not incorporate subscriptions"),
				(.dSubscriptionTimeout, "subscriptions always timeout")]
			.compactMap { (option, name) in contains(option) ? name : nil }
	}

}

struct ZPrintMode: OptionSet, CustomStringConvertible {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let     dNone = ZPrintMode(rawValue: 1 <<  0)
	static let      dOps = ZPrintMode(rawValue: 1 <<  1) // operations
	static let      dFix = ZPrintMode(rawValue: 1 <<  2) // disappearing ideas
	static let      dLog = ZPrintMode(rawValue: 1 <<  3) // miscellaneous
	static let     dEdit = ZPrintMode(rawValue: 1 <<  4) // become first responder funny business
	static let     dFile = ZPrintMode(rawValue: 1 <<  5) // parsing, error handling
	static let     dUser = ZPrintMode(rawValue: 1 <<  6) // user interruption of busy loops
	static let     dTime = ZPrintMode(rawValue: 1 <<  7) // stopwatch
	static let     dData = ZPrintMode(rawValue: 1 <<  8) // core data
	static let    dClick = ZPrintMode(rawValue: 1 <<  9) // mouse click
	static let    dSpeed = ZPrintMode(rawValue: 1 << 10) // "
	static let    dNames = ZPrintMode(rawValue: 1 << 11) // decorate idea text with record names
	static let    dFocus = ZPrintMode(rawValue: 1 << 12) // push, /, bookmarks
	static let    dError = ZPrintMode(rawValue: 1 << 13) // error handling
	static let    dAdopt = ZPrintMode(rawValue: 1 << 14) // orphans
	static let    dCloud = ZPrintMode(rawValue: 1 << 15) // cloud read
	static let    dFetch = ZPrintMode(rawValue: 1 << 16) // children
	static let    dCross = ZPrintMode(rawValue: 1 << 17) // core data cross store relationships
	static let    dNotes = ZPrintMode(rawValue: 1 << 18) // essays
	static let    dExist = ZPrintMode(rawValue: 1 << 19) // core data existence check
	static let    dTrack = ZPrintMode(rawValue: 1 << 20) // tool tip tracking
	static let   dImages = ZPrintMode(rawValue: 1 << 21) // "
	static let   dAccess = ZPrintMode(rawValue: 1 << 22) // write lock
	static let   dRemote = ZPrintMode(rawValue: 1 << 23) // arrival from cloud
	static let   dWidget = ZPrintMode(rawValue: 1 << 24) // lookup, hit tests
	static let   dTimers = ZPrintMode(rawValue: 1 << 25) // assure completion
	static let   dLevels = ZPrintMode(rawValue: 1 << 26) // fetching depth
	static let   dMoving = ZPrintMode(rawValue: 1 << 27) // moving and dragging ideas
	static let  dMigrate = ZPrintMode(rawValue: 1 << 28) // migrating to core data and cloud
	static let dRegister = ZPrintMode(rawValue: 1 << 29) // creating and registering ZRecords

	var description: String { return descriptions.joined(separator: kSpace) }

	var descriptions: [String] {
		return [(.dOps,      "      op"),
				(.dFix,      "     fix"),
				(.dLog,      "     log"),
				(.dFile,     "    file"),
				(.dTime,     "    time"),
				(.dEdit,     "    edit"),
				(.dUser,     "    user"),
				(.dData,     "    data"),
				(.dNames,    "    name"),
				(.dNotes,    "    note"),
				(.dFocus,    "   focus"),
				(.dSpeed,    "   speed"),
				(.dError,    "   error"),
				(.dAdopt,    "   adopt"),
				(.dCloud,    "   cloud"),
				(.dCross,    "   cross"),
				(.dClick,    "   click"),
				(.dExist,    "   exist"),
				(.dTrack,    "   track"),
				(.dFetch,    " fetched"),
				(.dAccess,   "  access"),
				(.dWidget,   "  widget"),
				(.dRemote,   "  remote"),
				(.dImages,   "  images"),
				(.dTimers,   "  timers"),
				(.dLevels,   "  levels"),
				(.dMoving,   "  moving"),
				(.dMigrate,  " migrate"),
				(.dRegister, "register")]
			.compactMap { (option, name) in contains(option) ? name : nil }
	}

}

extension ZMainController {

	@IBAction func debugInfoButtonAction(_ button: ZButton) {
		gToggleDebugMode(.dDebugInfo)
		gSignal([.spDebug, .spMain])
	}

}

var gDebugModes : ZDebugMode {
	get { return ZDebugMode(         rawValue: getPreferencesInt(for: kDebugModes, defaultInt: 0)) }
	set { setPreferencesInt(newValue.rawValue,                   for: kDebugModes) }
}

var gPrintModes : ZPrintMode {
	get { return ZPrintMode(         rawValue: getPreferencesInt(for: kPrintModes, defaultInt: 0)) }
	set { setPreferencesInt(newValue.rawValue,                   for: kPrintModes) }
}

var gCoreDataMode : ZCoreDataMode {
	get { return ZCoreDataMode(      rawValue: getPreferencesInt(for: kCoreDataMode, defaultInt: 0)) }
	set { setPreferencesInt(newValue.rawValue,                   for: kCoreDataMode) }
}

func printFancy(_ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  let t = test, !t() { return }
	let fancy = (surround == nil) ? message : message.surround(with: surround!)
	FOREGROUND {
		print(fancy)
	}
}

func printDebug(_ mode: ZPrintMode, prefix: String = "  ", _ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  gPrintModes.contains(mode) {
		printFancy("\(mode): " + prefix + message, surround: surround, test)
	}
}
