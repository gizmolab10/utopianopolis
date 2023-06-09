//
//  ZTrait.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

struct ZNoteVisibilityMode: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let mSelf     = ZNoteVisibilityMode(rawValue: 1 << 0)
	static let mChildren = ZNoteVisibilityMode(rawValue: 1 << 1)
	static let mHidden   = ZNoteVisibilityMode(rawValue: 1 << 2)
}

var gActiveTraitTypes : ZTraitTypesArray { return [.tNote, .tEmail, .tHyperlink, .tPhone] }
var  gPopupTraitTypes : ZTraitTypesArray { return gActiveTraitTypes + [.tSeparator, .tClear] }

enum ZTraitType: String { // stored in database: do not change

	case tSeparator = "-"
	case tDuration  = "!" // accumulative
	case tMoney     = "$" //      "
	case tAssets    = "a" // can have multiple
	case tDate      = "d"
	case tEmail     = "e"
	case tHyperlink = "h"
	case tNote      = "n"
	case tPhone     = "p"
	case tClear     = "x"
	case tEssay     = "w"

	var title         : String? { return description?.capitalized }
	var isEssayOrNote :   Bool  { return [.tNote, .tEssay].contains(self) }

	var heightRatio: CGFloat {
		switch self {
			case .tHyperlink,
				 .tMoney,
				 .tDate: return 1.0
			default:     return 0.66667
		}
	}

	var description: String? {
		switch self {
			case .tSeparator: return kLineOfDashes
			case .tPhone:     return "PHONE NUMBER"
			case .tClear:     return "REMOVE ALL"
			case .tHyperlink: return "HYPERLINK"
			case .tEmail:     return "EMAIL"
			case .tEssay:     return "ESSAY"
			case .tNote:      return "NOTE"
			default:          return nil
		}
	}

}

@objc(ZTrait)
class ZTrait: ZTraitAssets {

	@NSManaged var       strings : StringsArray?
	@NSManaged var     ownerLink : String?
	@NSManaged var      ownerRID : String?
	@NSManaged var        format : String?
	@NSManaged var          type : String?
	@NSManaged var          text : String?
	@NSManaged var    visibility : NSNumber?
	override   var unwrappedName : String { return text                   ?? emptyName }
	override   var decoratedName : String { return text                   ?? kNoValue }
	override   var    typePrefix : String { return traitType?.description ?? kEmpty }
	override   var     isInScope : Bool   { return ownerZone?.isInScope   ?? false }
	override   var  passesFilter : Bool   { return gSearchFilter.contains(.fNotes) && (traitType?.isEssayOrNote ?? false) }
	var                hasNoText : Bool   { return text?.isEmpty ?? true }
	var               _traitType : ZTraitType?
	var               _ownerZone : Zone?
	var                needsSave = false

	var attributedText : NSMutableAttributedString? {
		didSet {
			text   = attributedText?.string;
			format = attributedText?.attributesAsString
		}
	}

	override var         cloudProperties: StringsArray { return ZTrait.cloudProperties }
	override var optionalCloudProperties: StringsArray { return ZTrait.optionalCloudProperties }

	override class var cloudProperties: StringsArray {
		return [#keyPath(type),
				#keyPath(text),
				#keyPath(strings)] +
			optionalCloudProperties +
			super.cloudProperties
	}

	override class var optionalCloudProperties: StringsArray {
		return [#keyPath(ownerLink),
				#keyPath(ownerRID),
				#keyPath(format)] +
			super.optionalCloudProperties
	}

	// MARK: - visibility
	// MARK: -

	var     showsSelf : Bool { get { return visibilityMode?.contains(.mSelf)     ?? false } set { setVisibilityMode(.mSelf,     to: newValue) } }
	var   showsHidden : Bool { get { return visibilityMode?.contains(.mHidden)   ?? false } set { setVisibilityMode(.mHidden,   to: newValue) } }
	var showsChildren : Bool { get { return visibilityMode?.contains(.mChildren) ?? false } set { setVisibilityMode(.mChildren, to: newValue) } }

	func setVisibilityMode(_ mode: ZNoteVisibilityMode, to: Bool) {
		if  var v = visibilityMode {
			if  to {
				v.insert(mode)
			} else {
				v.remove(mode)
			}

			visibilityMode = v
		} else {
			visibilityMode = mode
		}
	}

	var visibilityMode : ZNoteVisibilityMode? {
		get {
			if  let n = visibility?.intValue {
				return ZNoteVisibilityMode(rawValue: n)
			}

			return nil
		}

		set {
			let      n = newValue?.rawValue ?? 0
			visibility = NSNumber(value: n)
		}
	}

	func stateFor(_ type: ZNoteVisibilityIconType) -> Bool? {
		switch type {
			case .tSelf:     return showsSelf
			case .tHidden:   return showsHidden
			case .tChildren: return showsChildren
		}
	}

	func toggleVisibilityFor(_ type: ZNoteVisibilityIconType) {
		switch type {
			case .tSelf:     showsSelf     = !showsSelf
			case .tHidden:   showsHidden   = !showsHidden
			case .tChildren: showsChildren = !showsChildren
		}
	}

	// MARK: - initialize
	// MARK: -

	static func uniqueTrait(from dict: ZStorageDictionary, in databaseID: ZDatabaseID) -> ZTrait {
		let result = uniqueTrait(recordName: dict.recordName, in: databaseID)

		result.temporarilyIgnoreNeeds {
			do {
				try result.extractFromStorageDictionary(dict, of: kTraitType, into: databaseID)
			} catch {
				printDebug(.dError, "\(error)")    // de-serialization
			}
		}

		return result
	}

	func deepCopy(into dbID: ZDatabaseID) -> ZTrait {
		let theCopy = ZTrait.uniqueTrait(recordName: gUniqueRecordName, in: dbID)

		copyInto(theCopy)

		return theCopy
	}

	static func uniqueTrait(recordName: String?, in databaseID: ZDatabaseID) -> ZTrait {
		return uniqueZRecord(entityName: kTraitType, recordName: recordName, in: databaseID) as! ZTrait
	}

	// MARK: - owner
	// MARK: -

	var ownerZone: Zone? {
		if  _ownerZone == nil,
			let  owner  = ownerLink?.maybeZone {
			_ownerZone  = owner
		}

		return _ownerZone
	}

	override var color: ZColor? {
		get { return ownerZone?.color }
		set { ownerZone?.color = newValue }
	}

	override func orphan() {
		ownerZone?.setTraitText(nil, for: traitType)

		ownerLink = nil
	}

	override func adopt(recursively: Bool = false) {
		if  let  owner = ownerZone,
			let traits = ownerZone?.traits,
			let      t = traitType, traits[t] == nil {
			removeState(.needsAdoption)

			owner.addTrait(self)
		}
	}

	// MARK: - text
	// MARK: -

	var noteText: NSMutableAttributedString? {
		get {
			var        string : NSMutableAttributedString?
			let       isEmpty = hasNoText

			whileSelfIsCurrentTrait {
				if  isEmpty {
					text      = kDefaultNoteText

					updateSearchables()
				}

				if  let     s = text {
					string    = NSMutableAttributedString(string: s)

					if  let f = format {
						string?.attributesAsString = f
					} else if isEmpty || text! == kDefaultNoteText {
						string?.addAttribute(.font, value: kDefaultEssayFont, range: NSRange(location: 0, length: string!.length))
					}
				}
			}

			return string
		}

		set {
			whileSelfIsCurrentTrait {
				if  let string = newValue {
					text 	   = string.string
					format 	   = string.attributesAsString

					if  hasNoText {
						text = kDefaultNoteText
					}

					// THE NEXT STATEMENT IS THE ONLY code which gathers assets for images,
					// side-effect for each dropped image:
					// it creates and adds an asset and a ZFile

					extractAssets(from: string)
					updateSearchables()
				}
			}
		}
	}

    override var emptyName: String {
        if  let tType = traitType {
            switch tType {
				case .tEmail:     return "email address"
				case .tPhone:     return "phone number"
				case .tHyperlink: return "hyperlink"
				default:          break
            }
        }

        return kEmpty
    }

    var traitType: ZTraitType? {
        get {
            if  _traitType == nil,
				var t       = type {
				if  t      == ZTraitType.tEssay.rawValue {
					t       = ZTraitType.tNote .rawValue
					type    = t
				}

				_traitType  = ZTraitType(rawValue: t)
            }

            return _traitType
        }

        set {
            if newValue    != _traitType {
                _traitType  = newValue
                type        = newValue?.rawValue
            }
        }
    }

	func whileSelfIsCurrentTrait(during: Closure) {
		let     prior = gCurrentTrait // can be called within recursive traversal of notes within notes, etc.
		gCurrentTrait = self
		during()
		gCurrentTrait = prior
	}

	func updateSearchables() {
		let searchableTypes : ZTraitTypesArray = [.tNote, .tEssay, .tEmail, .tHyperlink, .tPhone]

		if  let type = traitType, searchableTypes.contains(type) {
			strings = text?.searchable.componentsSeparatedBySpace
		}
	}

	func updateFontSize(_ increment: Bool) -> Bool {
		var updated       = false

		if  let f         = format {
			let separator = "NSFontSizeAttribute (f) "
			var parts     = f.components(separatedBy: separator)

			for (index, part) in parts.enumerated() {
				if  index              != 0 {
					let subSeparator    = kColon
					var subParts        = part.components(separatedBy: subSeparator)
					let number          = subParts[0]

					if  var value       = number.integerValue {
						value          += (increment ? 1 : -1) * 6

						if  value      >= 12 { 	    // minimum font size is 12
							subParts[0] = "\(value)"
							updated     = true
						}
					}

					parts[index]        = subParts.joined(separator: subSeparator)
				}
			}

			format = parts.joined(separator: separator)
		}

		return updated
	}

}
