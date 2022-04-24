//
//  ZAssets.swift
//  Zones
//
//  Created by Jonathan Sand on 4/10/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

// //////////////////////////////////////////////////////////// //
//                                                              //
// manages Thoughtful's asset cache folder                      //
// registers assets by original filename, length, trait & uuid  //
// called by note text attachment, trait & image                //
//                                                              //
// persist assets & uuids in traits                             //
//                                                              //
// //////////////////////////////////////////////////////////// //

let gAssetCache = ZAssetCache()

class ZAssetWrapper : NSObject {
	var textAttachment : NSTextAttachment?
	var originalName   : String?
	var assetLength    : Int?
	var fileURL        : URL?
	var asset          : CKAsset?
	var owner          : ZTrait?
	var uuid           : UUID?
}

class ZAssetCache: NSObject {

	var   currentTrait : ZTrait? { return gCurrentEssay?.noteTrait }
	var  assetWrappers = [          ZAssetWrapper ]()
	var lengthRegistry = [Int    :  ZAssetWrapper ]()
	var   nameRegistry = [String :  ZAssetWrapper ]()
	var   uuidRegistry = [String :  ZAssetWrapper ]()
	var  traitRegistry = [ZTrait : [ZAssetWrapper]]()

	// MARK:- assets
	// MARK:-

	func removeAssets(for trait: ZTrait) {}
	func removeAsset(for fileName: String) {}

	func createAssetFromImage(x image: ZImage, for fileName: String, ownedBy trait: ZTrait?) -> CKAsset? {
		if  let         w = wrapperFor(fileName) {
			return      w  .asset
		} else if let url = writeImage(x: image, to: fileName) {
			let     asset = CKAsset(fileURL: url)

			if  let dropped = gEssayView?.dropped,
				dropped == fileName,
				trait?.updateAssetNames(from: asset, imageFileName: fileName) ?? false {
				gEssayView?.dropped = nil
			}

			if  createWrapperForAsset(asset, fileName: fileName, ownedBy: trait) != nil {
				return asset
			}
		}

		return nil
	}

	func xassetStringForTrait(_ trait: ZTrait) -> String {
		var results = [String]()

		if  let wrappers = traitRegistry[trait] {
			for wrapper in wrappers {
				if  let o = wrapper.originalName, let u = wrapper.uuid?.uuidString {
					results.append(o + gSeparatorAt(level: 1) + u)
				}
			}
		}

		return results.joined(separator: gSeparatorAt(level: 0))
	}

	func xextractAssetsFrom(_ string: String?, for trait: ZTrait) {
		if  let parts = string?.componentsSeparatedAt(level: 0) {
			for part in parts {
				let subparts = part.componentsSeparatedAt(level: 1)

				if  subparts.count > 1 {
					let name = subparts[0]
					let uuid = subparts[1]

				}
			}
		}
	}

	// MARK:- wrappers
	// MARK:-

	func createWrapperForFileName(_ name: String, url: URL, ownedBy trait: ZTrait? = nil) -> ZAssetWrapper {
		var              w = ZAssetWrapper()
		if  let    wrapper = nameRegistry[name] {
			w              = wrapper
		} else {
			w.originalName = name
			w.owner        = trait
			w.asset        = trait?.assetForName(name)

			addWrapper(w, for: name)
			addWrapper(w, for: trait)
		}

		w.fileURL          = url

		return w
	}

	func createWrapperForFileNameOnly(_ fileName: String) -> ZAssetWrapper {
		let                        url = gFiles.imageURL(for: fileName)
		let                          w = createWrapperForFileName(fileName, url: url, ownedBy: currentTrait)
		if  w.asset                   != nil {
			return w
		} else if let           length = FileManager.default.contents(atPath: url.path)?.count,
			let                  array = currentTrait?.assets {
			for asset in array {
				if  let           data = asset.data,
					length            == data.count {
					w           .asset = asset

					if  let uuidString = asset.uuidString {
						let uuid       = UUID(uuidString: uuidString)

						w        .uuid = uuid
					}

					if  let     length = asset.length {
						w .assetLength = length
					}

					printDebug(.dImages, "ASSET   " + fileName)

//					return w
				}
			}
		}

		printDebug(.dImages, "NOASSET " + fileName)

		return w
	}

	@discardableResult func createWrapperForAsset(_ asset: CKAsset?, fileName: String? = nil, ownedBy trait: ZTrait?) -> ZAssetWrapper? {
		if  let                 u = asset?.uuidString,
			let                 l = asset?.length,
			let              uuid = UUID(uuidString: u) {
			var                 w = ZAssetWrapper()
			if  let       wrapper = lengthRegistry[l] {
				w                 = wrapper
			} else if let wrapper = uuidRegistry[u] {
				w                 = wrapper
			} else if let    name = fileName,
				let       wrapper = nameRegistry[name] {
				w                 = wrapper
			} else {
				w.uuid            = uuid
				w.asset           = asset
				w.owner           = trait
				w.assetLength     = l
				w.originalName    = fileName
				uuidRegistry[u]   = w
				lengthRegistry[l] = w

				addWrapper(w, for: trait)
				addWrapper(w, for: fileName)
			}

			return w
		}

		return nil
	}

	private func wrapperFor(_ fileName: String) -> ZAssetWrapper? {
		let parts = fileName.components(separatedBy: ".")

		if  parts.count > 1 {
			let extent = parts[1]

			if  extent.length > 5 {
				let  uuid = parts[0]

				return uuidRegistry[uuid]
			}
		}

		return nameRegistry[fileName]
	}

	private func addWrapper(_ wrapper: ZAssetWrapper, for fileName: String?) {
		if let name = fileName {
			nameRegistry[name] = wrapper
		}
	}

	private func addWrapper(_ wrapper: ZAssetWrapper, for iTrait: ZTrait?) {
		if  let trait  = iTrait {
			var array  : [ZAssetWrapper]? = traitRegistry[trait]
			if  array == nil {
				array  = [ZAssetWrapper]()
				traitRegistry[trait] = array
			}

			array?.append(wrapper)
		}
	}

	// MARK:- asset url
	// MARK:-

	func textAttachment(forx fileName: String) -> NSTextAttachment? {
		if  let url = assetFileURL(x: fileName) {
			do {
				let attach = try NSTextAttachment(fileWrapper: FileWrapper(url: url, options: []))

				return attach
			} catch {
				printDebug(.dImages, "ERROR   \(error)") // original file name is useless
			}
		}

		return nil
	}

	private func writeImage(x image: ZImage, to originalName: String? = nil) -> URL? {
		let url = assetFileURL(x: originalName)

		url?.writeImage(image, addOriginalImageName: originalName)

		return url
	}

	private func assetFileURL(x fileName: String? = nil) -> URL? {
		if  let            name = fileName {
			if  let     wrapped = wrapperFor(name),
				let       asset = wrapped.owner?.assetForName(name) {
				let         url = asset.fileURL
				wrapped.fileURL = url
				return url
			} else {
				let           w = createWrapperForFileNameOnly(name)

				return w.fileURL
			}
		}

		return nil
	}

}
