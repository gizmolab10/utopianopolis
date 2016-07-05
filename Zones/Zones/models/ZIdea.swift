//
//  ZIdea.swift
//  Zones
//
//  Created by Jonathan Sand on 7/3/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


class ZIdea : NSManagedObject {


    @NSManaged var text: String
    @NSManaged var parent: ZIdea
    @NSManaged var subordinates: [ZIdea]


}