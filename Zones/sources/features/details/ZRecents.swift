//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZFocusKind: Int {
	case eSelected
	case eEdited
}

let gRecents     = ZRecents(ZDatabaseID.recentsID)
var gRecentsRoot : Zone? { return gRecents.rootZone }
var gRecentsHere : Zone? { return gRecentsHereMaybe ?? gRecentsRoot }

class ZRecents : ZSmallMapRecords {

	override var rootZone : Zone? {
		get {
			return gMineCloud?.recentsZone
		}

		set {
			if  let n = newValue {
				gMineCloud?.recentsZone = n
			}
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		let        mine = gMineCloud
		if  let newRoot = mine?.maybeZoneForRecordName(kRecentsRootName) {
			rootZone    = newRoot

			newRoot.needProgeny()
			onCompletion?(0)
		} else {
			mine?.assureRecordExists(withRecordID: CKRecordID(recordName: kRecentsRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let                ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecordID(recordName: kRecentsRootName))
				self.rootZone               = Zone.create(record: ckRecord, databaseID: .mineID)
				self.rootZone?.directAccess = .eProgenyWritable
				self.rootZone?.zoneName     = kRecentsRootName

				self.rootZone?.needProgeny()
				onCompletion?(0)
			}
		}
	}

	override func push(_ zone: Zone? = gHere, intoNotes: Bool = false) {
		if !gPushIsDisabled,
		    rootZone != nil {
			var here  = zone

			if  intoNotes {
				here  = gCurrentEssayZone
			}

			if  let   pushMe = here, gHasFinishedStartup { // avoid confusing recents upon relaunch
				let bookmark = bookmarkTargeting(pushMe) ?? addNewBookmark(for: pushMe, action: .aCreateBookmark)

				bookmark?.moveZone(into: currentHere, at: 0)

				let           b = updateCurrentRecent()

				if  let  parent = b?.parentZone,
					let   index = b?.siblingIndex, index != 0 {
					parent.moveChildIndex(from: index, to: 0)
				}
			}
		}
	}

	func object(for id: String) -> NSObject? {
		let parts = id.components(separatedBy: kColonSeparator)

		if  parts.count == 2 {
			if  parts[0] == "note" {
				return ZNote .object(for: parts[1], isExpanded: false)
			} else {
				return ZEssay.object(for: parts[1], isExpanded: true)
			}
		}

		return nil
	}

	// MARK:- focus
	// MARK:-

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let    current = currentBookmark {
			return current.focusThrough(atArrival)
		}

		return false
	}

	override func go(down: Bool, amongNotes: Bool = false, moveCurrent: Bool = false, atArrival: Closure? = nil) {
		if  currentBookmark == nil {
			gRecents.push()
		}

		let   maxIndex = working.count - 1
		let     bottom = working[maxIndex]
		let        top = working[0]

		if  down {                         // move top to bottom
			if  let parent = top.parentZone {
				let    end = parent.count

				parent.moveChildIndex(from: 0, to: end)
			}
		} else {
			if  let parent = bottom.parentZone,
				let    end = bottom.siblingIndex {

				parent.moveChildIndex(from: end, to: 0)
			}
		}

		if  let t = working[0].bookmarkTarget {
			gHere = t

			t.grab()

			if  gIsEssayMode,
				let note = t.note {
				gEssayView?.resetCurrentEssay(note)
			}
		}

		gRedrawMaps()
	}

	@discardableResult override func pop(_ zone: Zone? = gHereMaybe) -> Bool {
		if  let   target = zone,
			let bookmark = workingBookmark(for: target),
			let    index = bookmark.siblingIndex {
			bookmark.parentZone?.children.remove(at: index)

			return true
		}

		return false
	}

}
