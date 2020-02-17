//
//  ZGridController.swift
//  iFocus
//
//  Created by Jonathan Sand on 6/24/19.
//  Copyright © 2019 Zones. All rights reserved.
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


class ZGridController: UICollectionViewController {
	
	
	var selectionOnly = true
	var       extends = false
	

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.register(ZGridCell.self, forCellWithReuseIdentifier: "gridCell")
		update()
	}
	

	func update() {
		collectionView.reloadData()
	}
	

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return 9
	}
	

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath as IndexPath) as! ZGridCell
		cell.addBorder(thickness: 0.5, radius: 5.0, color: ZColor.lightGray.cgColor)
		cell.backgroundColor = .clear
		cell.title.textColor = .blue
		cell.title.text = ""
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
			case .idExtend: 						if 		  extends { cell.backgroundColor = ZColor.lightGray }
			case .idUp, .idDown, .idLeft, .idRight: if !selectionOnly { cell.backgroundColor = ZColor.lightGray }
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
				redrawGraph()
				self.update()
			}

			switch gridIID {
			case .idCollapse,
				 .idExpand:   gGraphEditor.expand(gridIID == .idExpand)
			case .idUp:       gGraphEditor.move(up:  true,  selectionOnly: selectionOnly)
			case .idDown:     gGraphEditor.move(up:  false, selectionOnly: selectionOnly)
			case .idLeft:     gGraphEditor.move(out: true,  selectionOnly: selectionOnly)  { complete() }
			case .idRight:    gGraphEditor.move(out: false, selectionOnly: selectionOnly)  { complete() }
			case .idFocus:    gFocusRing.focus(kind: .eSelected) { gGraphEditor.redrawGraph() }; return
			case .idMove:     selectionOnly = !selectionOnly // only a toggle, does nothing else
			case .idExtend:   break // extends = !extends // disabled for now
			}
			
			complete()
		}
	}

}
