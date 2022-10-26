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
	var  nextGeneration : ZTraverseArray { get }
	@discardableResult func traverseHierarchy(inReverse : Bool, _ closure: ZTraverseToStatusClosure) -> ZTraverseStatus
}

extension ZPseudoView : ZTraverse {
	var  nextGeneration : [ZTraverse] { return subpseudoviews }
	@discardableResult func traverseHierarchy(inReverse : Bool = false, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus { return staticTraverseHierarchy(inReverse: inReverse, from: self, block) }
}

extension ZView : ZTraverse {
	var  nextGeneration : [ZTraverse] { return subviews }
	@discardableResult func traverseHierarchy(inReverse : Bool = false, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus { return staticTraverseHierarchy(inReverse: inReverse, from: self, block) }
}

func staticTraverseHierarchy(inReverse : Bool = false, from: ZTraverse, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus {
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
