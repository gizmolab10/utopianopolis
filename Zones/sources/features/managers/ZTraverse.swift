//
//  ZTraverse.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

typealias ZTraverseArray           = [ZTraverse]
typealias ZTraverseToStatusClosure = (ZTraverse) -> (ZTraverseStatus)

protocol ZTraverse {

	var nextGeneration : ZTraverseArray { get }

	func traverseHierarchy(_ closure: ZTraverseToStatusClosure) -> ZTraverseStatus
}

func staticTraverseHierarchy(from: ZTraverse, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus {
	var status = block(from)

	if  status == .eContinue {
		for child in from.nextGeneration {

			status = staticTraverseHierarchy(from: child, block)

			if  status == .eStop {
				break						// halt traversal
			}
		}
	}

	return status
}

extension ZPseudoView {
	var nextGeneration : [ZTraverse] { return subpseudoviews }
	@discardableResult func traverseHierarchy(_ block: ZTraverseToStatusClosure) -> ZTraverseStatus { staticTraverseHierarchy(from: self, block) }

}

extension ZView : ZTraverse {

	var nextGeneration : [ZTraverse] { return subviews }

	@discardableResult func traverseHierarchy(_ block: ZTraverseToStatusClosure) -> ZTraverseStatus { staticTraverseHierarchy(from: self, block) }

}
