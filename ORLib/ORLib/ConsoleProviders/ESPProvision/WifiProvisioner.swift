/*
 * Copyright 2017, OpenRemote Inc.
 *
 * See the CONTRIBUTORS.txt file in the distribution for a
 * full listing of individual contributors.
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
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import ESPProvision
import Foundation
import os

class WifiProvisioner {
    private static let logger = Logger(
           subsystem: Bundle.main.bundleIdentifier!,
           category: String(describing: ESPProvisionProvider.self)
       )

    private var deviceConnection: DeviceConnection?
    var sendDataCallback: SendDataCallback?

    private var wifiScanning = false
    private var wifiNetworks = [ESPWifiNetwork]()

    init(deviceConnection: DeviceConnection?, sendDataCallback: SendDataCallback?) {
        self.deviceConnection = deviceConnection
        self.sendDataCallback = sendDataCallback
    }

    public func startWifiScan() {
        guard deviceConnection?.isConnected ?? false else {
            sendWifiScanError(ESPProviderError.notConnected)
            return
        }
        wifiScanning = true
        scanWifi()
    }

    public func stopWifiScan() {
        wifiScanning = false
    }

    private func scanWifi() {
        deviceConnection?.device?.scanWifiList { wifiList, error in
            if let wifiList {
                if self.wifiScanning {
                    var wifiNetworksChanged = false
                    for network in wifiList {
                        if let networkIndex = self.wifiNetworks.firstIndex(where: { $0.ssid == network.ssid }) {
                            if self.wifiNetworks[networkIndex].rssi != network.rssi {
                                wifiNetworksChanged = true
                                self.wifiNetworks.remove(at: networkIndex)
                                self.wifiNetworks.append(network)
                            }
                        } else {
                            wifiNetworksChanged = true
                            self.wifiNetworks.append(network)
                        }
                    }
                    if !self.wifiNetworks.isEmpty && wifiNetworksChanged {
                        self.sendDataCallback?([
                            DefaultsKey.providerKey: Providers.espprovision,
                            DefaultsKey.actionKey: Actions.startWifiScan,
                            DefaultsKey.dataKey: ["networks": self.wifiNetworks
                                .map { ["ssid": $0.ssid, "signalStrength": $0.rssi] } ]
                        ])
                    }
                    self.scanWifi()
                }
            } else {
                if let error {
                    Self.logger.warning("Error during wifi scan: \(error.localizedDescription)")
                    if case ESPWiFiScanError.emptyResultCount = error {
                        // This list is empty, not an error, just loop to continue scanning
                        if self.wifiScanning {
                            self.scanWifi()
                        }
                    } else {
                        self.wifiScanning = false
                        self.sendWifiScanError(ESPProviderError.communicationError, errorMessage: error.localizedDescription)
                    }
                } else {
                    self.wifiScanning = false
                    self.sendWifiScanError(ESPProviderError.communicationError, errorMessage: "Did not receive any content from device")
                }
            }
        }
    }

    private func sendWifiScanError(_ error: ESPProviderError? = nil, errorMessage: String? = nil) {
        var data: [String: Any] = ["id": deviceConnection?.deviceId?.uuidString ?? "N/A"]
        if let error {
            data["errorCode"] = error.rawValue
        }
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        self.sendDataCallback?([
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.actionKey: Actions.stopWifiScan,
            DefaultsKey.dataKey: data
        ])
    }

    public func sendWifiConfiguration(ssid: String, password: String) {
        guard deviceConnection?.isConnected ?? false else {
            sendWifiConfigurationStatus(connected: false, error: ESPProviderError.notConnected)
            return
        }
        wifiScanning = false
        deviceConnection?.device?.provision(ssid: ssid, passPhrase: password, threadOperationalDataset: nil) { status in
            // This block gets called multiple times
            // provision callback with status configApplied
            // then
            // provision callback with status failure(ESPProvision.ESPProvisionError)
            // or
            // provision callback with status success
            switch status {
            case .success:
                self.sendWifiConfigurationStatus(connected: true)
            case .failure(let error):
                self.sendWifiConfigurationStatus(connected: false, error: self.mapESPProvisionError(error), errorMessage: error.localizedDescription)
            case .configApplied:
                // This is an intermediate information we're not interested in forwarding
                break
            }
        }
    }

    private func mapESPProvisionError(_ error: Error) -> ESPProviderError? {
        guard let error = error as? ESPProvisionError else {
            return ESPProviderError.genericError
        }
        switch error {
        case .sessionError:
            return ESPProviderError.communicationError
        case .configurationError, .wifiStatusError, .wifiStatusDisconnected:
            return ESPProviderError.wifiConfigurationError
        case .wifiStatusAuthenticationError:
            return ESPProviderError.wifiAuthenticationError
        case .wifiStatusNetworkNotFound:
            return ESPProviderError.wifiNetworkNotFound
        case .wifiStatusUnknownError:
            return ESPProviderError.wifiCommunicationError
        case .threadStatusError, .threadStatusDettached, .threadDatasetInvalid, .threadStatusNetworkNotFound, .threadStatusUnknownError:
            // These are Thread related errors, a protocol we're not supporting
            return ESPProviderError.genericError
        case .unknownError:
            return ESPProviderError.genericError
        }
    }

    private func sendWifiConfigurationStatus(connected: Bool, error: ESPProviderError? = nil, errorMessage: String? = nil) {
        var data: [String: Any] = ["connected": connected]
        if let error {
            data["errorCode"] = error.rawValue
        }
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        self.sendDataCallback?([
            DefaultsKey.actionKey: Actions.sendWifiConfiguration,
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.dataKey: data
        ])
    }
}
