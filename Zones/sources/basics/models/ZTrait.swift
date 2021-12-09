//
//  ZTrait.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZTraitType: String { // stored in database: do not change
	case tDuration  = "!" // accumulative
	case tMoney     = "$" //      "
	case tAssets    = "a" // can have multiple
	case tHyperlink = "h"
	case tEmail     = "e"
	case tEssay     = "w"
	case tDate      = "d"
	case tNote      = "n"

	static var activeTypes: [ZTraitType] { return [.tEmail, .tHyperlink] }

	var heightRatio: CGFloat {
		switch self {
			case .tHyperlink,
				 .tMoney,
				 .tDate: return 1.0
			default:     return 0.66667
		}
	}

	var title: String? { return description?.capitalized }

	var description: String? {
		switch self {
			case .tHyperlink: return "LINK"
			case .tEmail:     return "EMAIL"
			case .tEssay:     return "ESSAY"
			case .tNote:      return "NOTE"
			default:          return nil
		}
	}

}

@objc(ZTrait)
class ZTrait: ZTraitAssets {

	@NSManaged    var  strings : StringsArray?
	@NSManaged    var ownerRID : String?
	@NSManaged    var   format : String?
	@NSManaged    var     type : String?
	@NSManaged    var     text : String?
    override var unwrappedName : String { return text ?? emptyName }
	override var decoratedName : String { return text ?? kNoValue }
	override var    typePrefix : String { return traitType?.description ?? kEmpty }
	var             _ownerZone : Zone?
	var             _traitType : ZTraitType?

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
		return [#keyPath(ownerRID),
				#keyPath(format)] +
			super.optionalCloudProperties
	}

	// MARK: - initialize
	// MARK: -

	static func uniqueTrait(from dict: ZStorageDictionary, in dbID: ZDatabaseID) -> ZTrait {
		let result = uniqueTrait(recordName: dict.recordName, in: dbID)

		result.temporarilyIgnoreNeeds {
			do {
				try result.extractFromStorageDictionary(dict, of: kTraitType, into: dbID)
			} catch {
				printDebug(.dError, "\(error)")    // de-serialization
			}
		}

		return result
	}

	func deepCopy(dbID: ZDatabaseID) -> ZTrait {
		let theCopy = ZTrait.uniqueTrait(recordName: gUniqueRecordName, in: dbID)

		copyInto(theCopy)

		return theCopy
	}

	static func uniqueTrait(recordName: String?, in dbID: ZDatabaseID) -> ZTrait {
		return uniqueZRecord(entityName: kTraitType, recordName: recordName, in: dbID) as! ZTrait
	}

	// MARK: - owner
	// MARK: -

	var ownerZone: Zone? {
		if  _ownerZone == nil {
			_ownerZone  = gRemoteStorage.maybeZoneForRecordName(ownerRID)
		}

		return _ownerZone
	}

	override var isAdoptable: Bool { return ownerRID != nil }

	override func orphan() {
		ownerZone?.setTraitText(nil, for: traitType)

		ownerRID = nil
	}

	override func adopt(recursively: Bool = false) {
		if  let      o = ownerZone,
			let traits = ownerZone?.traits,
			let      t = traitType, traits[t] == nil {
			removeState(.needsAdoption)

			o.addTrait(self)
		}
	}

	// MARK: - text
	// MARK: -

	var noteText: NSMutableAttributedString? {
		get {
			var        string : NSMutableAttributedString?
			let       isEmpty = text == nil || text!.isEmpty || text! == kEssayDefault

			whileSelfIsCurrentTrait {
				if  isEmpty {
					text      = kEssayDefault

					updateSearchables()
				}

				if  let     s = text {
					string    = NSMutableAttributedString(string: s)

					if  let f = format {
						string?.attributesAsString = f
					} else if isEmpty {
						string?.addAttribute(.font, value: kDefaultEssayFont, range: NSRange(location: 0, length: text!.length))
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

					if  text?.isEmpty ?? true {
						text = kEssayDefault
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
				case .tHyperlink: return "hyperlink"
				default:          break
            }
        }

        return kEmpty
    }

    var traitType: ZTraitType? {
        get {
            if  _traitType == nil, type != nil {
                _traitType  = ZTraitType(rawValue: type!)
            }

            return _traitType
        }

        set {
            if newValue != _traitType {
                _traitType = newValue
                type       = newValue?.rawValue
            }
        }
    }

	override var matchesFilterOptions: Bool { return gFilterOption.contains(.fNotes) }

	func whileSelfIsCurrentTrait(during: Closure) {
		let     prior = gCurrentTrait // can be called within recursive traversal of notes within notes, etc.
		gCurrentTrait = self
		during()
		gCurrentTrait = prior
	}

	func updateSearchables() {
		let searchables: [ZTraitType] = [.tNote, .tEssay, .tEmail, .tHyperlink]

		if  let  tt = traitType, searchables.contains(tt) {
			strings = text?.searchable.components(separatedBy: kSpace)
		}
	}

	func updateEssayFontSize(_ increment: Bool) -> Bool {
		var updated       = false

		if  let f         = format {
			let separator = "NSFontSizeAttribute (f) "
			var parts     = f.components(separatedBy: separator)

			for (index, part) in parts.enumerated() {
				if  index              != 0 {
					let subSeparator    = kColonSeparator
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
