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

class SplashViewController: UIViewController {

    var host: String?
    var project: ProjectConfig?
    
    var displaySettings = false
   
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (displaySettings) {
            self.performSegue(withIdentifier: Segues.goToSettingsView, sender: self)
            displaySettings = false
            return
        }
        if let userDefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement),
           let projectsData = userDefaults.data(forKey: DefaultsKey.projectsConfigurationKey),
           let selectedProjectId = userDefaults.string(forKey: DefaultsKey.projectKey) {
            
            let projects = try? JSONDecoder().decode([ProjectConfig].self, from: projectsData)
            
            if let projects = projects {
                print("Known projects \(projects)")
                print("Selected project \(selectedProjectId)")
                
                if let selectedProject = projects.first(where: { $0.id == selectedProjectId } ) {
                    project = selectedProject
                    self.performSegue(withIdentifier: Segues.goToWebView, sender: self)
                    return
                }
            }
        }
        self.performSegue(withIdentifier: Segues.goToWizardDomainView, sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.goToWebView {
            let orViewController = segue.destination as! ORViewcontroller
            
            if let project = project {
  
                // TODO: replace with proper URL creation
                orViewController.targetUrl = project.targetUrl

//                orViewController.baseUrl = host
            }
        }
    }

}
