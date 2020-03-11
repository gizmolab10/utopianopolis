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
	func recordName() -> String?
	func identifier() -> String?
	static func object(for id: String, isExpanded: Bool) -> NSObject?
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
	var        ringPrime : NSObject?         { return currentIndex > topIndex ? nil : ring[currentIndex] }
	var    possiblePrime : NSObject?         { return gCurrentEssay }
    var          atPrime : Bool              { return isPrime && currentIndex >= 0 && currentIndex <= topIndex }
	var          isEmpty : Bool              { return ring.count == 0 || possiblePrime == nil }
	var          isEssay : Bool              { return true }
	var visibleRingTypes : ZTinyDotTypeArray { return ZTinyDotTypeArray() }

	func storeRingIDs() { setRingContents(for: isEssay, strings: objectIDs) }
	func fetchRingIDs() { objectIDs = getRingContents(for: isEssay) }
	func clear() { ring.removeAll(); storeRingIDs() }

	override init() {
		super.init()
		fetchRingIDs()
		gRingView?.copyObjects(from: ring)
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
					addToRing(object)
				}
			}
		}
	}

	func object(for id: String) -> NSObject? {
		let parts = id.components(separatedBy: kNameSeparator)

		if  parts.count == 2 {
			if  parts[0] == "note" {
				return ZNote .object(for: parts[1], isExpanded: false)
			} else {
				return ZEssay.object(for: parts[1], isExpanded: true)
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

	private func pushOrReplace(onto newIndex: Int? = nil) -> Int? { // nil means not inserted
		var        result  : Int?
		if  let      item  = possiblePrime {
			if  let index  = indexInRing(item) {
				result     = index

				replaceInRing(item, at: index)
			} else if let index = newIndex {
				result          = index

				addToRing(item, at: index)
			} else {
				result     = ring.count - 1

				addToRing(item)
			}

			storeRingIDs()
		}

		return result
	}

	func push() {
		if  possiblePrime != nil {
			currentIndex   = currentIndex + 1

			if  topIndex < 0 || !atPrime {
				if  let        index = primeIndex {
					currentIndex     = index   // prevent duplicates in stack
				} else if currentIndex >= topIndex {
					if  let    index = pushOrReplace() {
						currentIndex = index

						gRingView?.updateNecklace()
					}
				} else if let  index = pushOrReplace(onto: currentIndex) { // BUG: wrong index
					currentIndex     = index

					gRingView?.updateNecklace()
				}
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

		signalMultiple([.eMain, .eCrumbs, .eRing]) // update breadcrumbs and ring
	}

    func pop() {
		if  ring.count > (isEssay ? 0 : 1),
			let i = primeIndex {
			removeFromRing(at: i)
			storeRingIDs()
			gRingView?.updateNecklace()
			goBack()
        }
	}

	@discardableResult func popAndRemoveEmpties() -> Bool {
		pop()
		removeEmpties()

		return isEmpty
	}

	func removeEmpties() {
		var removals = ZObjectsArray()

		for item in ring {
			if  let note = item as? ZNote,
				let zone = note.zone,
				!zone.hasTrait(for: .tNote) {
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

	@discardableResult func removeFromStack(_ iItem: NSObject?, okayToRecurse: Bool = true) -> Bool {
		if  let note = iItem as? ZNote,
			let zone = note.zone {
			for (index, item) in ring.enumerated() {
				if  let    other = item as? ZNote,
					let ringZone = other.zone,
					ringZone === zone {
					removeFromRing(at: index)
					removeEmpties()
					storeRingIDs()
					gRingView?.updateNecklace()

					if  isEmpty {
						gCurrentEssay = nil   // so won't reappear in necklace on relaunch
						gControllers.swapGraphAndEssay(force: .graphMode)
					} else if index == currentIndex || note == gCurrentEssay {
						goBack()
					}

					return true
				}
			}
		}

		return false
	}

	func removeFromRing(at index: Int) {
		printDebug(.ring, "r  remove: \(ring[index])")
		ring.remove(at: index)
	}

	func replaceInRing(_ object: NSObject, at index: Int) {
		ring[index] = object

		printDebug(.ring, "r replace: \(ring[index])")
	}

	func addToRing(_ object: NSObject, at iIndex: Int? = nil) {
		let index = iIndex ?? ring.count

		if  iIndex == nil {
			ring.append(object)
		} else {
			ring.insert(object, at: index)
		}

		printDebug(.ring, "r     add: \(ring[index])")
	}

}
