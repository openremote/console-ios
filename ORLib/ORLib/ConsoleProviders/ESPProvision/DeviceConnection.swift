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

import CoreBluetooth
import ESPProvision
import Foundation
import os

class DeviceConnection {
    private static let logger = Logger(
           subsystem: Bundle.main.bundleIdentifier!,
           category: String(describing: ESPProvisionProvider.self)
       )

    private var deviceRegistry: DeviceRegistry
    var sendDataCallback: SendDataCallback?

    private var username = "UNUSED"
    private var pop = "abcd1234"

    private var bleStatus = BLEStatus.disconnected

    // Those are reset when disconnected from device
    // deviceId and device are set as soon as connection is attempted, configChannel only when connection is established
    public private(set) var deviceId: UUID?
    public private(set) var device: ORESPDevice?
    private var configChannel: ORConfigChannel?

    init(deviceRegistry: DeviceRegistry, sendDataCallback: SendDataCallback?) {
        self.deviceRegistry = deviceRegistry
        self.sendDataCallback = sendDataCallback
    }

    public func connectTo(deviceId idToConnectTo: String, pop: String? = nil, username: String? = nil) {
        self.pop = pop ?? "abcd1234"
        self.username = username ?? "UNUSED"

        if deviceRegistry.bleScanning {
            deviceRegistry.stopDevicesScan()
        }
        if let devId = UUID(uuidString: idToConnectTo), let dev = deviceRegistry.getDeviceWithId(devId) {
            device = dev.device
            deviceId = devId
            device!.bleDelegate = self
            device!.connect(delegate: self) { status in
                // ESPBLEDelegate.peripheralConnected() is called before this callback
                // We only care about this one as we want a full session and not just a BLE connection

                switch status {
                case .connected:
                    self.bleStatus = .connected
                    self.configChannel = ORConfigChannel(device: self.device!)
                    self.sendConnectToDeviceStatus(status: ESPProviderConnectToDeviceStatus.connected)
                    break
                case .failedToConnect(let error):
                    self.bleStatus = .disconnected
                    self.sendConnectToDeviceStatus(status: ESPProviderConnectToDeviceStatus.connectionError, error: self.mapESPSessionError(error), errorMessage: error.localizedDescription)
                case .disconnected:
                    self.bleStatus = .disconnected
                    self.device?.bleDelegate = nil
                    self.device = nil
                    self.sendConnectToDeviceStatus(status: ESPProviderConnectToDeviceStatus.disconnected)
                    // Only reset deviceId after sending the status as it's part of the message
                    self.deviceId = nil
                    break
                }
            }
        } else {
            self.sendConnectToDeviceStatus(status: ESPProviderConnectToDeviceStatus.connectionError, error: .unknownDevice, errorMessage: "Provided ID does not match any discovered device")
        }
    }

    private func mapESPSessionError(_ error: Error) -> ESPProviderError? {
        guard let error = error as? ESPSessionError else {
            return ESPProviderError.genericError
        }
        switch error {
        case .sessionInitError, .sessionNotEstablished, .sendDataError, .versionInfoError:
            return ESPProviderError.communicationError
        case .bleFailedToConnect:
            return ESPProviderError.bleCommunicationError
        case .securityMismatch, .encryptionError, .noPOP, .noUsername:
            return ESPProviderError.securityError
        case .softAPConnectionFailure:
            return ESPProviderError.genericError
        }
    }

    public func disconnectFromDevice() {
        if let device {
            device.disconnect()
        }
    }

    private func sendConnectToDeviceStatus(status: String, error: ESPProviderError? = nil, errorMessage: String? = nil) {
        var data: [String: Any] = ["id": deviceId?.uuidString ?? "N/A", "status": status]
        if let error {
            data["errorCode"] = error.rawValue
        }
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        self.sendDataCallback?([
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.actionKey: Actions.connectToDevice,
            DefaultsKey.dataKey: data
        ])
    }

    var isConnected: Bool {
        device != nil && configChannel != nil
    }

    func exitProvisioning() {
        if !isConnected {
            sendExitProvisioningError(.notConnected, errorMessage: "No connection established to device")
            return
        }
        Task {
            do {
                try await configChannel!.exitProvisioning()
            } catch {
                sendExitProvisioningError(.communicationError, errorMessage: error.localizedDescription)
            }
        }
    }

    // TODO: this code is duplicated, how to improve ?
    func sendExitProvisioningError(_ error: ESPProviderError, errorMessage: String?) {
        var data: [String: Any] = ["errorCode": error.rawValue]
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        self.sendDataCallback?([
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.actionKey: Actions.exitProvisioning,
            DefaultsKey.dataKey: data
        ])
    }

}

extension DeviceConnection: ESPBLEDelegate {
    func peripheralConnected() {
        bleStatus = .connected
    }

    func peripheralDisconnected(peripheral: CBPeripheral, error: Error?) {
        bleStatus = .disconnected
        self.configChannel = nil
        self.device?.bleDelegate = nil
        self.device = nil
        self.sendConnectToDeviceStatus(status: ESPProviderConnectToDeviceStatus.disconnected)
        // Only reset deviceId after sending the status as it's part of the message
        self.deviceId = nil
    }

    func peripheralFailedToConnect(peripheral: CBPeripheral?, error: Error?) {
        bleStatus = .disconnected
    }
}

extension DeviceConnection: ESPDeviceConnectionDelegate {
    func getProofOfPossesion(forDevice: ESPDevice, completionHandler: @escaping (String) -> Void) {
        Self.logger.info("Asked for PoP")
        completionHandler(self.pop)
    }

    func getUsername(forDevice: ESPDevice, completionHandler: @escaping (String?) -> Void) {
        Self.logger.info("Asked for username")
        completionHandler(self.username)
    }
}

private enum BLEStatus {
    case connecting
    case connected
    case disconnected
}
