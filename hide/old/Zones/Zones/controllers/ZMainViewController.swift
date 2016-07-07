//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData
import Cocoa


class ZMainViewController: ZViewController, ZOutlineViewDataSource, NSFetchedResultsControllerDelegate {


    @IBOutlet weak var outlineView: ZOutlineView?


    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int { return fetchedResultsController.count }


    let fetchedResultsController: NSFetchedResultsController = {
        var request:       NSFetchRequest = NSFetchRequest(entityName: "ZIdea")
//        request.sortDescriptors           = [NSSortDescriptor(key: "", ascending: false)]
//        request.predicate                 = NSPredicate("")
//        request.includesPendingChanges    = YES
        let f: NSFetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil);
        f.delegate                        = self

        return f
    }()


}

