//
//  ZRing.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

let gEssayRing = ZRing()

protocol ZIdentifiable {
	func identifier() -> String?
	static func object(for id: String) -> NSObject?
}

protocol ZToolable {
	func toolName() -> String?
	func toolColor() -> ZColor?
}

class ZRing: NSObject {

    var             ring = ZObjectsArray ()
    var     currentIndex = -1
    var       priorIndex = -1
	var         topIndex : Int               { return ring.count - 1 }
	var        ringPrime : NSObject?         { return ring[currentIndex] }
	var    possiblePrime : NSObject?         { return gCurrentEssay }
    var          atPrime : Bool              { return currentIndex >= 0 && currentIndex <= topIndex && isPrime }
	var          isEmpty : Bool              { return ring.count == 0 || possiblePrime == nil }
	var          isEssay : Bool              { return true }
	var visibleRingTypes : ZTinyDotTypeArray { return ZTinyDotTypeArray() }

	func storeRingIDs() { setRingContents(for: isEssay, strings: objectIDs) }
	func fetchRingIDs() { objectIDs = getRingContents(for: isEssay) }
	func clear() { ring.removeAll(); storeRingIDs() }

	override init() {
		super.init()
		fetchRingIDs()
	}

	var isPrime : Bool {
		guard let essay = ringPrime as? ZNote else { return false }

		return gCurrentEssay == essay
	}

	// MARK:- ring
    // MARK:-

    var primeIndex : Int? {
		if  let p = possiblePrime {
			for (index, item) in ring.enumerated() {
				if  p == item {
					return index
				}
			}
		}

        return nil
    }

	var objectIDs: [String] {
		get {
			var ids = [String]()

			for item in ring {
				if  let object = item as? ZIdentifiable,
					let     id = object.identifier() {
					ids.append(id)
				}
			}

			return ids
		}

		set {
			let ids: [String] = newValue

			for id in ids {
				if  let object = object(for: id),
					indexInRing(object) == nil {
					ring.append(object)
				}
			}
		}
	}

	func object(for id: String) -> NSObject? {
		let parts = id.components(separatedBy: kSeparator)

		if  parts.count == 2 {
			if  parts[0] == "note" {
				return ZNote .object(for: parts[1])
			} else {
				return ZEssay.object(for: parts[1])
			}
		}

		return nil
	}

    func dump() {
        if  gDebugMode.contains(.focus) {
//            for (index, item) in ring.enumerated() {
//                let isCurrentIndex = index == currentIndex
//                let prefix = isCurrentIndex ? "                   •" : ""
//                columnarReport(prefix, item.unwrappedName)
//            }
        }
    }

	private func indexInRing(_ item: AnyObject) -> Int? {
		if  let o = item as? ZNote {
			for (index, ringItem) in ring.enumerated() {
				if  let r = ringItem as? ZNote,
					o.zone == r.zone {
					return index
				}
			}
		}

		return nil
	}

	private func pushUnique(_ newIndex: Int? = nil) -> Int? { // nil means not inserted
		if  let     item = possiblePrime {
			if let index = indexInRing(item) {
				return index
			} else if let index = newIndex {
				ring.insert(item, at: index)
				storeRingIDs()

				return index
			} else {
				ring.append(item)
				storeRingIDs()

				return ring.count - 1
			}
		}

		return nil
	}

	func push() {
        currentIndex = currentIndex + 1

        if  topIndex < 0 || !atPrime {
            if  let index = primeIndex {
                currentIndex = index   // prevent duplicates in stack
            } else if currentIndex >= topIndex {
				if let index = pushUnique() {
					currentIndex = index
				}
            } else if let index = pushUnique(currentIndex) {
				currentIndex = index
			}
        }
    }

    func goBack(extreme: Bool = false) {
        if  let    index = primeIndex {
            currentIndex = index
        }

        if  currentIndex <= 0 || currentIndex > topIndex {
            currentIndex = topIndex	// wrap around
        } else if extreme {
            currentIndex = 0
        } else if currentIndex == topIndex || atPrime {
            currentIndex -= 1
        }

        go()
    }

    func goForward(extreme: Bool = false) {
        if  let     index = primeIndex {
            currentIndex  = index
        }

        if  currentIndex == topIndex {
            currentIndex  = 0	// wrap around
        } else if  extreme {
            currentIndex  = topIndex
        } else if  currentIndex < topIndex {
            currentIndex += 1
        }

        go()
    }

    func go() {
        if  0          <= currentIndex,
            ring.count  > currentIndex, (!atPrime ||
            priorIndex != currentIndex) {
            priorIndex  = currentIndex

			update()
        }
    }

	func update() {
		if  isEmpty {
			gCurrentEssay = nil

			gControllers.swapGraphAndEssay()
		} else if let item = ring[currentIndex] as? ZNote {
			gEssayView?.resetCurrentEssay(item)
		}

		gControllers.signalMultiple([.eMain, .eRing, .eCrumbs]) // update breadcrumbs and ring
	}

    func pop() {
		if  ring.count > (isEssay ? 0 : 1),
			let i = primeIndex {
			ring.remove(at: i)
			storeRingIDs()
        }

		goBack()
	}

	func popAndRemoveEmpties() -> Bool {
		pop()
		removeEmpties()

		return isEmpty
	}

	func removeEmpties() {
		var removals = ZObjectsArray()

		for item in ring {
			if  let note = item as? ZNote,
				let zone = note.zone,
				!zone.hasTrait(for: .eNote) {
				removals.append(item)
			}
		}

		for item in removals {
			removeFromStack(item)
		}

		if  isEmpty {
			gCurrentEssay = nil
		}
	}

	func removeFromStack(_ iItem: NSObject?) {
		if  let note = iItem as? ZNote,
			let zone = note.zone {
			for (index, item) in ring.enumerated() {
				if  let    other = item as? ZNote,
					let ringZone = other.zone,
					ringZone === zone {
					ring.remove(at: index)
					removeEmpties()
					storeRingIDs()

					if !isEmpty,
						index == currentIndex {
						goBack()
					}

					return
				}
			}
		}
	}

}
