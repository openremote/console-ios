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

class SettingsViewController: UITableViewController {
  
    private var projects = [ProjectConfig]()
    private var selectedProjectId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let userDefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement) {
            selectedProjectId = userDefaults.string(forKey: DefaultsKey.projectKey)
            if let projectsData = userDefaults.data(forKey: DefaultsKey.projectsConfigurationKey) {
                projects = (try? JSONDecoder().decode([ProjectConfig].self, from: projectsData)) ?? []
            }
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        navigationItem.title = "Projects"
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        if editing {
            navigationItem.leftBarButtonItem = nil
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        }
        super.setEditing(editing, animated: animated)
    }

    @objc func addTapped() {
        self.performSegue(withIdentifier: Segues.addProject, sender: self)
    }
    
    @objc func doneTapped() {
        self.dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? projects.count : 1
    }
   
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: ProjectTableViewCell = tableView.dequeueReusableCell(withIdentifier: "ProjectCell", for: indexPath) as! ProjectTableViewCell
            let project = projects[indexPath.row]
            cell.setProject(project)
            cell.accessoryType = project.id == selectedProjectId ? .checkmark : .none
            cell.tintColor = UIColor(named: "or_green")
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoProjectsCell", for: indexPath)
            cell.isHidden = projects.count > 0
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        var rowsToReload = [IndexPath]()
        if editingStyle == .delete {
            let removedProject = projects.remove(at: indexPath.row)
            if projects.isEmpty {
                rowsToReload.append(IndexPath(row: 0, section: 1))
            } else {
                if selectedProjectId == removedProject.id {
                    selectProject(id: projects.first?.id)
                    rowsToReload.append(IndexPath(row: 0, section: 0))
                }
            }
            
            do {
                if let userDefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement) {
                    let data = try JSONEncoder().encode(projects)
                    userDefaults.setValue(data, forKey: DefaultsKey.projectsConfigurationKey)
                }
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print(error.localizedDescription)
            }
        }
        if !rowsToReload.isEmpty {
            tableView.reloadRows(at: rowsToReload, with: .none)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if let currentlySelectedProject = projects.first(where:{ $0.id == selectedProjectId }),
           let cellIndex = projects.firstIndex(of: currentlySelectedProject),
           let previousCell = tableView.cellForRow(at: IndexPath(row: cellIndex, section: indexPath.section)) {
                previousCell.accessoryType = .none
        }

        let project = projects[indexPath.row]
        selectProject(id: project.id)
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
        }
        doneTapped()
    }
    
    private func selectProject(id: String?) {
        selectedProjectId = id
        if let userDefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement) {
            if id != nil {
                userDefaults.setValue(id, forKey: DefaultsKey.projectKey)
            } else {
                userDefaults.removeObject(forKey: DefaultsKey.projectKey)
            }
        }
    }
}
