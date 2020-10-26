//
//  ORAppConfig.swift
//  GenericApp
//
//  Created by Michael Rademaker on 21/10/2020.
//  Copyright © 2020 OpenRemote. All rights reserved.
//

import UIKit

struct ORAppConfig: Codable {
    let id: Int32
    let realm: String
    let initialUrl: String
    let url: String
    let menuEnabled: Bool
    let menuPosition: String?
    let menuImage: String?
    let primaryColor: String?
    let secondaryColor: String?
    let links: [ORLinkConfig]?
}
