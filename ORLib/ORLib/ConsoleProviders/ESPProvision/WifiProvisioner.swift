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
    var callbackChannel: CallbackChannel?

    private var loopDetector: LoopDetector
    var searchWifiTimeout: TimeInterval {
        get {
            loopDetector.timeout
        }
        set {
            self.loopDetector = LoopDetector(timeout: newValue, maxIterations: searchWifiMaxIterations)
        }

    }
    var searchWifiMaxIterations: Int {
        get {
            loopDetector.maxIterations
        }
        set {
            self.loopDetector = LoopDetector(timeout: searchWifiTimeout, maxIterations: newValue)
        }

    }

#if DEBUG
// TODO: see https://stackoverflow.com/a/60267724 for improvement
    public private(set) var wifiScanning = false
#else
    private var wifiScanning = false
#endif

    private var wifiNetworks = [ESPWifiNetwork]()

    init(deviceConnection: DeviceConnection?, callbackChannel: CallbackChannel?, searchWifiTimeout: TimeInterval = 120, searchWifiMaxIterations: Int = 25) {
        self.deviceConnection = deviceConnection
        self.callbackChannel = callbackChannel
        self.loopDetector = LoopDetector(timeout: searchWifiTimeout, maxIterations: searchWifiMaxIterations)
    }

    public func startWifiScan() {
        guard deviceConnection?.isConnected ?? false else {
            sendWifiScanError(ESPProviderErrorCode.notConnected)
            return
        }
        wifiScanning = true
        loopDetector.reset()
        scanWifi()
    }

    public func stopWifiScan(sendMessage: Bool = true) {
        wifiScanning = false
        if sendMessage {
            callbackChannel?.sendMessage(action: Actions.stopWifiScan, data: nil)
        }
    }

    private func scanWifi() {
        if self.loopDetector.detectLoop() {
            self.stopWifiScan(sendMessage: false)
            self.sendWifiScanError(ESPProviderErrorCode.timeoutError)
            return
        }
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
                        self.callbackChannel?.sendMessage(action: Actions.startWifiScan,
                                                         data: ["networks": self.wifiNetworks.map { ["ssid": $0.ssid, "signalStrength": $0.rssi] } ])
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
                        self.sendWifiScanError(ESPProviderErrorCode.communicationError, errorMessage: error.localizedDescription)
                    }
                } else {
                    self.wifiScanning = false
                    self.sendWifiScanError(ESPProviderErrorCode.communicationError, errorMessage: "Did not receive any content from device")
                }
            }
        }
    }

    private func sendWifiScanError(_ error: ESPProviderErrorCode? = nil, errorMessage: String? = nil) {
        var data: [String: Any] = ["id": deviceConnection?.deviceId?.uuidString ?? "N/A"]
        if let error {
            data["errorCode"] = error.rawValue
        }
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        callbackChannel?.sendMessage(action: Actions.stopWifiScan, data: data)
    }

    public func sendWifiConfiguration(ssid: String, password: String) {
        guard deviceConnection?.isConnected ?? false else {
            sendWifiConfigurationStatus(connected: false, error: ESPProviderErrorCode.notConnected)
            return
        }
        stopWifiScan()
        deviceConnection?.device?.provision(ssid: ssid, passPhrase: password, threadOperationalDataset: nil) { status in
            // This block gets called multiple times
            // provision callback with status configApplied
            // then
            // provision callback with status failure(ESPProvision.ESPProvisionError)
            // or
            // provision callback with status success
            WifiProvisioner.logger.trace("provision callback with status: \(String(describing:status))")

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

    private func mapESPProvisionError(_ error: Error) -> ESPProviderErrorCode? {
        guard let error = error as? ESPProvisionError else {
            return ESPProviderErrorCode.genericError
        }
        switch error {
        case .sessionError:
            return ESPProviderErrorCode.communicationError
        case .configurationError, .wifiStatusError, .wifiStatusDisconnected:
            return ESPProviderErrorCode.wifiConfigurationError
        case .wifiStatusAuthenticationError:
            return ESPProviderErrorCode.wifiAuthenticationError
        case .wifiStatusNetworkNotFound:
            return ESPProviderErrorCode.wifiNetworkNotFound
        case .wifiStatusUnknownError:
            return ESPProviderErrorCode.wifiCommunicationError
        case .threadStatusError, .threadStatusDettached, .threadDatasetInvalid, .threadStatusNetworkNotFound, .threadStatusUnknownError:
            // These are Thread related errors, a protocol we're not supporting
            return ESPProviderErrorCode.genericError
        case .unknownError:
            return ESPProviderErrorCode.genericError
        }
    }

    private func sendWifiConfigurationStatus(connected: Bool, error: ESPProviderErrorCode? = nil, errorMessage: String? = nil) {
        var data: [String: Any] = ["connected": connected]
        if let error {
            data["errorCode"] = error.rawValue
        }
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        callbackChannel?.sendMessage(action: Actions.sendWifiConfiguration, data: data)
    }
}
