//
//  PersistentController.swift
//  HamsterApp
//
//  Created by morse on 16/3/2023.
//

import CoreData

struct PersistentController {
  private static let sharedResult: Result<PersistentController, Error> = Result {
    try PersistentController()
  }

  static var shared: PersistentController {
    get throws {
      try sharedResult.get()
    }
  }

  let container: NSPersistentContainer
  init() throws {
    let name = "HamsterApp"

    let storeURL = try FileManager.appGroupContainerURL()
      .appendingPathComponent("\(name).sqlite")

    let storeDescription = NSPersistentStoreDescription(url: storeURL)
    container = NSPersistentContainer(name: name)
    container.persistentStoreDescriptions = [storeDescription]
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
  }
}
