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

let gAssets = ZAssetCache()

class ZAssetWrapper : NSObject {
	var textAttachment : NSTextAttachment?
	var originalName   : String?
	var length         : Int?
	var asset          : CKAsset?
	var owner          : ZTrait?
	var key            : UUID?
}

class ZAssetCache: NSObject {

	var   currentTrait : ZTrait?
	var  assetWrappers = [          ZAssetWrapper ]()
	var lengthRegistry = [Int    :  ZAssetWrapper ]()
	var   nameRegistry = [String :  ZAssetWrapper ]()
	var   uuidRegistry = [String :  ZAssetWrapper ]()
	var  traitRegistry = [ZTrait : [ZAssetWrapper]]()

	@discardableResult func createWrapper(for asset: CKAsset?, for fileName: String? = nil, ownedBy trait: ZTrait?) -> ZAssetWrapper? {
		if  let                 u = asset?.value(forKeyPath: "_UUID") as? String,
			let                 l = asset?.value(forKeyPath: "_size") as? Int,
			let              uuid = UUID(uuidString: u) {
			var                 w = ZAssetWrapper()
			if  let       wrapper = lengthRegistry[l] {
				w                 = wrapper
			} else {
				w.length          = l
				w.asset           = asset
				w.owner           = trait
				w.key             = uuid
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

	func addWrapper(_ wrapper: ZAssetWrapper, for fileName: String?) {
		if let name = fileName {
			nameRegistry[name] = wrapper
		}
	}

	func addWrapper(_ wrapper: ZAssetWrapper, for iTrait: ZTrait?) {
		if  let trait  = iTrait {
			var array  : [ZAssetWrapper]? = traitRegistry[trait]
			if  array == nil {
				array  = [ZAssetWrapper]()
				traitRegistry[trait] = array
			}

			array?.append(wrapper)
		}
	}

	func removeAssets(for trait: ZTrait) {

	}

	func removeAsset(for fileName: String) {

	}

	// MARK:- main API
	// MARK:-

	func createAsset(from image: ZImage, for fileName: String, ownedBy trait: ZTrait?) -> CKAsset? {
		if  let         w = wrapperFor(fileName) {
			return      w  .asset
		} else if let url = writeImage(image, to: fileName) {
			let         a = CKAsset(fileURL: url)

			if  let     _ = createWrapper(for: a, for: fileName, ownedBy: trait) {
				return a
			}
		}

		return nil
	}

	func wrapperFor(_ fileName: String) -> ZAssetWrapper? {
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

	func writeImage(_ image: ZImage, to originalName: String? = nil) -> URL? {
		let url = assetFileURL(originalName)

		url?.writeImage(image, addOriginalImageName: originalName)

		return url
	}

	func textAttachment(for fileName: String) -> NSTextAttachment? {
		if  let url = assetFileURL(fileName) {
			do {
				let attach = try NSTextAttachment(fileWrapper: FileWrapper(url: url, options: []))

				return attach
			} catch {
				printDebug(.dImages, "ERROR   \(error)") // original file name is useless
			}
		}

		return nil
	}

	func assetFileURL(_ fileName: String? = nil) -> URL? {
		if  let        name = fileName {
			if  let wrapped = wrapperFor(name) {
				return wrapped.asset?.fileURL
			} else {
				createWrapper(for: nil, for: name, ownedBy: currentTrait)
				printDebug(.dImages, "NOASSET " + name)

				return gFiles.assetDirectoryURL.appendingPathComponent(name)
			}
		}

		return nil
	}

}
