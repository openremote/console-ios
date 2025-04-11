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

class WizardDomainViewController: UIViewController {

    var configManager: ConfigManager?

    var domainName: String?

    @IBOutlet weak var domainTextInput: ORTextInput!
    @IBOutlet weak var nextButton: ORRaisedButton!
    @IBOutlet var boxView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let orGreenColor = UIColor(named: "or_green")

        nextButton.backgroundColor = orGreenColor
        nextButton.tintColor = UIColor.white
        boxView.layer.cornerRadius = 10
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        domainTextInput.textFieldDelegate = self
        domainTextInput.textField.autocorrectionType = .no
        domainTextInput.textField.autocapitalizationType = .none
        domainTextInput.textField.returnKeyType = .next
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.goToWizardAppView {
            switch configManager!.state {
            case .selectApp(_, let apps):
                let appViewController = segue.destination as! WizardAppViewController
                appViewController.apps = apps
                appViewController.configManager = self.configManager
            default:
                fatalError("Invalid state for segue")
            }
        } else if segue.identifier == Segues.goToWizardRealmView {
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
        if let domain = domainName {
            requestAppConfig(domain)
        }
    }
}

extension WizardDomainViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == domainTextInput.textField {
            if let s = domainTextInput.textField.text {
                domainName = s.replacingCharacters(in: Range(range, in: s)!, with: string).trimmingCharacters(in: .whitespacesAndNewlines)
                nextButton.isEnabled = !(domainName?.isEmpty ?? true)
            } else {
                nextButton.isEnabled = false
            }
        }
        return true
    }

    fileprivate func requestAppConfig(_ domain: String) {
        configManager = ConfigManager(apiManagerFactory: { url in
            HttpApiManager(baseUrl: url)
        })

        async {
            do {
                let state = try await configManager!.setDomain(domain: domain)
                print("State \(state)")
                switch state {
                case .selectDomain:
                    // Something wrong, we just set the domain
                    let alertView = UIAlertController(title: "Error", message: "Error occurred getting app config. Check your input and try again", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

                    self.present(alertView, animated: true, completion: nil)
                case .selectApp:
                    self.performSegue(withIdentifier: Segues.goToWizardAppView, sender: self)
                case .selectRealm:
                    self.performSegue(withIdentifier: Segues.goToWizardRealmView, sender: self)
                case.complete:
                    self.performSegue(withIdentifier: Segues.goToWebView, sender: self)
                }
            } catch {
                let alertView = UIAlertController(title: "Error", message: "Error occurred getting app config. Check your input and try again", preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alertView, animated: true, completion: nil)
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let input = textField.text, !input.isEmpty else {
            return false
        }

        if textField == domainTextInput.textField, let domain = domainName {
            domainTextInput.textField.resignFirstResponder()
            requestAppConfig(domain)
        }

        return true
    }
}
