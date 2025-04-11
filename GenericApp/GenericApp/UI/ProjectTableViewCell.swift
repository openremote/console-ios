/*
 * Copyright 2025, OpenRemote Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import UIKit
import ORLib


class ProjectTableViewCell: UITableViewCell {
    
    @IBOutlet weak var domainLabel: UILabel!
    @IBOutlet weak var appLabel: UILabel!
    @IBOutlet weak var realmLabel: UILabel!

    var project: ProjectConfig?
    
    func setProject(_ project: ProjectConfig) {
        self.project = project
        domainLabel.text = project.domain
        appLabel.text = "App: \(project.app)"
        realmLabel.text = project.realm != nil ? "Realm: \(project.realm!)" : ""
    }
}
