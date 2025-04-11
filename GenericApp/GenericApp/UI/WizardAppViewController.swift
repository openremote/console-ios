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
import DropDown

class WizardAppViewController: UIViewController {

    var configManager: ConfigManager?

    var apps: [String]?

    var appName: String?

    @IBOutlet weak var appTextInput: ORTextInput!
    @IBOutlet weak var nextButton: ORRaisedButton!
    @IBOutlet weak var boxView: UIView!
    
    @IBOutlet weak var appsSelectionButton: UIButton!
    var dropDown = DropDown()

    override func viewDidLoad() {
        super.viewDidLoad()

        let orGreenColor = UIColor(named: "or_green")

        nextButton.backgroundColor = orGreenColor
        nextButton.tintColor = UIColor.white
        
        boxView.layer.cornerRadius = 10
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        appTextInput.textFieldDelegate = self
        appTextInput.textField.autocorrectionType = .no
        appTextInput.textField.autocapitalizationType = .none
        appTextInput.textField.returnKeyType = .next
        
        if let apps = apps {
            dropDown.anchorView = appsSelectionButton
            // The list of items to display. Can be changed dynamically
            dropDown.dataSource = apps

            dropDown.selectionAction = { [weak self] (index, item) in
                self?.appsSelectionButton.setTitle(item, for: .normal)
            }
            
            appsSelectionButton.isHidden = false
            appTextInput.isHidden = true
        } else {
            appsSelectionButton.isHidden = true
            appTextInput.isHidden = false
        }
    }

    @IBAction func selectApp(_ sender: AnyObject) {
            dropDown.show()
        }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.goToWizardRealmView {
            switch configManager!.state {
            case .selectRealm(_, _, let realms):
                let realmViewController = segue.destination as! WizardRealmViewController
                realmViewController.realms = realms
                realmViewController.configManager = self.configManager
            default:
                fatalError("Invalid state for segue")
            }
        } else if segue.identifier == Segues.goToWebView {
            let orViewController = segue.destination as! ORViewcontroller
            
            switch configManager!.state {
            case .complete(let project):
                orViewController.targetUrl = project.targetUrl
            default:
                fatalError("Invalid state for segue")
            }
        }
    }

    @IBAction func nextButtonpressed(_ sender: UIButton) {
        selectApp()
    }
    
    private func selectApp() {
        let selectedApp: String?
        if apps != nil {
            selectedApp = dropDown.selectedItem
        } else {
            selectedApp = appName
        }

        if let selectedApp = selectedApp {
            print("Selected app >\(selectedApp)<")
            _ = try? configManager!.setApp(app: selectedApp)
            
            
            
            // TODO: check state, can we go to some other screen ?
            
            
            self.performSegue(withIdentifier: Segues.goToWizardRealmView, sender: self)
        } else {
            let alertView = UIAlertController(title: "Error", message: "Please \(apps != nil ? "select" : "enter") an application", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

            self.present(alertView, animated: true, completion: nil)
        }
    }
}
 
extension WizardAppViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == appTextInput.textField {
            if let s = appTextInput.textField.text {
                appName = s.replacingCharacters(in: Range(range, in: s)!, with: string).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let input = textField.text, !input.isEmpty else {
            return false
        }

        if textField == appTextInput.textField {
            appTextInput.textField.resignFirstResponder()
            selectApp()
        }

        return true
    }
}
