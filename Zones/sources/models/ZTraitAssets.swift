//
//  ZTraitAssets.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/18/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

class ZTraitAssets: ZRecord {

	@objc dynamic var     assets : [CKAsset]?
	@objc dynamic var assetNames :  String?
	override func cloudProperties() -> [String] { return ZTraitAssets.cloudProperties() }

	override class func cloudProperties() -> [String] {
		return [#keyPath(assetNames),
			    #keyPath(assets)] +
				super.cloudProperties()
	}

	// MARK:- attachment
	// MARK:-

	// ONLY called within set noteText, in call to
	// set attributed strings from format stored in trait
	//
	// check if file actually exist in assets folder
	// by successfully creating a wrapper
	// try using the filename passed in
	// then look up the the corresponding ASSET and try using ITS fileurl
	// if either exists, create a text attachment from the wrapper

	func textAttachment(for fileName: String) -> NSTextAttachment? {
		var     url = gFiles.imageURLInAssetsFolder(for: fileName)
		var wrapper : FileWrapper?
		var  extend : String?

		let grabWrapper = {
			do {
				wrapper = try FileWrapper(url: url, options: [])
				extend  = url.pathExtension
			} catch {}
		}

		grabWrapper()

		if  wrapper     == nil,
			let    asset = assetFromAssetNames(for: fileName) {
			let original = url
			url          = asset.fileURL

			grabWrapper()

			if  let e = extend, e.length > 8 {
				wrapper = nil

				do {
					try FileManager.default.moveItem(at: url, to: original)	   // rename asset url to original

					url = original

					grabWrapper()
					printDebug(.dImages, "RENAME   \(url)")
				} catch {}
			}
		}

		if  wrapper == nil {
			printDebug(.dImages, "MISSING  \(url)")

			return nil
		}

		return NSTextAttachment(fileWrapper: wrapper)
	}

	// MARK:- persistence
	// MARK:-

	// called during save note (in set note text)
	// and in read file (extract from storage dictionary)

	func assetFromImage(_ image: ZImage, for fileName: String) -> CKAsset? {
		if  let     asset = assetFromAssetNames(for: fileName) {
			return  asset
		} else if let url = writeImageIntoAssetsFolder(image, using: fileName) {
			let     asset = CKAsset(fileURL: url)    // side-effect creates asset for dropped image

			if  appendUniquelyToAssetNames(fileName, from: asset) {
				assets?.append(asset)
				needSave()

				FOREGROUND(after: 0.5) {
					gControllers.sync()
				}
			}

			return asset
		}

		return nil
	}

	func appendUniquelyToAssetNames(_ imageName: String, from asset: CKAsset) -> Bool {
		var         names = assetNames?.componentsSeparatedAt(level: 0) ?? []

		if  let  checksum = asset.data?.checksum {
			let separator = gSeparatorAt(level: 1)
			let assetName = imageName + separator + "\(checksum)"

			if !names.contains(assetName) {
				for (index, name) in names.enumerated() {
					let parts = name.componentsSeparatedAt(level: 1)

					if  parts.count > 1,
						parts[0] == imageName {
						names.remove(at: index)     // remove duplicate imageName and uuid

						break
					}
				}

				names.append(assetName)				// add imageName and asset's uuid
				printDebug(.dImages, "ADD NAME \(assetName)")

				assetNames = names.joined(separator: gSeparatorAt(level: 0))

				return true
			}
		}

		return false
	}

	func assetFromAssetNames(for name: String) -> CKAsset? {
		if  let items = assetNames?.componentsSeparatedAt(level: 0),
			let array = assets,
			array.count > 0 {
			for item in items {
				let parts = item.componentsSeparatedAt(level: 1)

				if  parts.count == 2,
					name == parts[0],
					let checksum = parts[1].integerValue {

					for asset in array {
						if  let  data  = asset.data {
							let delta  = abs(data.checksum - checksum)
							if  delta == 0 {
								return asset
							}
						}
					}
				}
			}
		}

		return nil
	}

	private func writeImageIntoAssetsFolder(_ image: ZImage, using originalName: String? = nil) -> URL? {
		if  let name = originalName {
			let url = gFiles.imageURLInAssetsFolder(for: name)

			if  url.writeImage(image) {
				return url
			}
		}

		// check if file exists at url

		return nil
	}

}
