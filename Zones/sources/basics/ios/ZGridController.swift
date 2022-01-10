//
//  ZGridController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/24/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation
import UIKit

enum ZGridID : Int {
	case idCollapse
	case idUp
	case idExpand
	case idLeft
	case idFocus
	case idRight
	case idMove
	case idDown
	case idExtend
}

// grid of buttons for easy use on iPhone

class ZGridController: UICollectionViewController {
	
	var selectionOnly = true
	var       extends = false

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.register(ZGridCell.self, forCellWithReuseIdentifier: "gridCell")
		update()
	}

	func gridUpdate() {
		collectionView.reloadData()
	}

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return 9
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath as IndexPath) as! ZGridCell
		cell.addBorder(thickness: 0.5, radius: 5.0, color: kLightGrayColor.cgColor)
		cell.backgroundColor = .clear
		cell.title.textColor = .blue
		cell.title.text = kEmpty
		cell.title.font = ZFont.systemFont(ofSize: 24.0)
		cell.title.isUserInteractionEnabled = false
		
		if  let    gridIID = ZGridID(rawValue: indexPath.row) {
			switch gridIID {
			case .idCollapse: cell.title.text = "⋺"
			case .idUp:       cell.title.text = "⇧"
			case .idExpand:   cell.title.text = "⋲"
			case .idLeft:     cell.title.text = "⇦"
			case .idFocus:    cell.title.text = "/"
			case .idRight:    cell.title.text = "⇨"
			case .idMove:     cell.title.text = "✍"
			case .idDown:     cell.title.text = "⇩"
			case .idExtend:   break // cell.title.text = "+"
			}

			switch gridIID {
			case .idExtend: 						if 		  extends { cell.backgroundColor = kLightGrayColor }
			case .idUp, .idDown, .idLeft, .idRight: if !selectionOnly { cell.backgroundColor = kLightGrayColor }
			default: break
			}
		}

		cell.addSubview(cell.title)
		cell.title.snp.makeConstraints { make in
			make.center.equalToSuperview()
		}

		return cell
	}
	
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if  let    gridIID = ZGridID(rawValue: indexPath.row) {

			let complete = {
				gSelecting.updateAfterMove()
				redrawMap()
				self.gridUpdate()
			}

			switch gridIID {
			case .idCollapse,
				 .idExpand:   gSelecting.currentMoveable.generationalUpdate(gridIID == .idExpand) { complete() }
			case .idUp:       gMapEditor.move(up:  true,  selectionOnly: selectionOnly)
			case .idDown:     gMapEditor.move(up:  false, selectionOnly: selectionOnly)
			case .idLeft:     gMapEditor.move(out: true,  selectionOnly: selectionOnly)           { complete() }
			case .idRight:    gMapEditor.move(out: false, selectionOnly: selectionOnly)           { complete() }
			case .idFocus:    gRecents.focus(kind: .eSelected) { gRedrawMap() }; return
			case .idMove:     selectionOnly = !selectionOnly // only a toggle, does nothing else
			case .idExtend:   break // extends = !extends // disabled for now
			}
			
			complete()
		}
	}

}
