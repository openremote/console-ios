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

import Foundation
import ESPProvision
import os

protocol ORESPProvisionManager {
    func searchESPDevices(devicePrefix: String, transport: ESPTransport, security: ESPSecurity) async throws -> [ORESPDevice]

    func stopESPDevicesSearch()
}

struct EspressifProvisionManager: ORESPProvisionManager {
    var provisionManager: ESPProvisionManager = ESPProvisionManager.shared


    // TODO: how can I protect against multiple potential callbacks and not call continuation multiple times ?

    public func searchESPDevices(devicePrefix: String, transport: ESPTransport, security: ESPSecurity = .secure) async throws -> [ORESPDevice] {
        return try await withCheckedThrowingContinuation { continuation in
            provisionManager.searchESPDevices(devicePrefix: devicePrefix, transport: transport, security: security) { deviceList, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: deviceList ?? [])
                }
            }
        }
    }

    public func stopESPDevicesSearch() {
        provisionManager.stopESPDevicesSearch()
    }
}

class DeviceRegistry {
    private static let logger = Logger(
           subsystem: Bundle.main.bundleIdentifier!,
           category: String(describing: ESPProvisionProvider.self)
       )

    private var devices: [DiscoveredDevice] = []
    private var devicesIndex: [UUID:DiscoveredDevice] = [:]


    // TODO: check if here or some place else or how to be set ?
    var sendDataCallback: SendDataCallback?
    var provisionManager: ORESPProvisionManager?

    public private(set) var bleScanning = false

    func enable() {
        provisionManager = EspressifProvisionManager(provisionManager: ESPProvisionManager.shared)
    }

    func disable() {
        if bleScanning {
            stopDevicesScan()
        }
        provisionManager = nil
    }

    public func startDevicesScan(prefix: String? = nil) {
        bleScanning = true
        resetDevicesList()
        devicesScan(prefix: prefix ?? "")
    }

    public func stopDevicesScan() {
        bleScanning = false
        provisionManager?.stopESPDevicesSearch()
    }

    private func devicesScan(prefix: String) {
        if let provisionManager {
            Task {
                do {
                    let deviceList = try await provisionManager.searchESPDevices(devicePrefix: prefix, transport: .ble, security: .secure)

                    if self.bleScanning { // If we're not scanning anymore, we don't report back
                        var devicesChanged = false
                        for device in deviceList {
                            // We need to assign an id to each device, so web app can refer to it
                            // At this stage, we name is also unique but having an id would allow duplicates at some point
                            if self.getDeviceNamed(device.name) == nil {
                                devicesChanged = true
                                let dev = DiscoveredDevice(device: device)
                                self.registerDevice(dev)
                            }
                        }
                        // If there are devices in the list and the list changed since the last time, we communicated to web app
                        if !self.devices.isEmpty && devicesChanged {
                            self.sendDataCallback?([
                                DefaultsKey.providerKey: Providers.espprovision,
                                DefaultsKey.actionKey: Actions.startBleScan,
                                DefaultsKey.dataKey: ["devices": self.devices.map { $0.info }]
                            ])
                        }
                        self.devicesScan(prefix: prefix)
                    }
                } catch {
                    Self.logger.warning("Error during device scan: \(error.localizedDescription)")

                    // The only error applicable to us here is espDeviceNotFound, we don't care about it
                    // All other possible errors are about camera for QR code or Soft AP
                    // Still be cautious about that and don't loop the scan for these kinds of errors
                    if let cssError = error as? ESPDeviceCSSError {
                        if case .espDeviceNotFound = cssError {
                            if self.bleScanning {
                                self.devicesScan(prefix: prefix)
                            }
                        } else { sendDeviceScanError(ESPProviderError.genericError) }
                    } else { sendDeviceScanError(ESPProviderError.genericError) }

                    // TODO: seems we can't have BLE permissions error here, but want to test

                }
            }
        }
    }

    private func sendDeviceScanError(_ error: ESPProviderError, errorMessage: String? = nil) {
        var data: [String: Any] = ["errorCode": error.rawValue]
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        self.sendDataCallback?([
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.actionKey: Actions.stopBleScan,
            DefaultsKey.dataKey: data
        ])
    }

    private func resetDevicesList() {
        devices = []
        devicesIndex = [:]
    }
    
    private func getDeviceNamed(_ name: String) -> DiscoveredDevice? {
        return devices.first(where: { $0.device.name == name })
    }

    func getDeviceWithId(_ id: UUID) -> DiscoveredDevice? {
        return devicesIndex[id]
    }

    private func registerDevice(_ device: DiscoveredDevice) {
        devices.append(device)
        devicesIndex[device.id] = device
    }
}

// TODO
/*private*/ struct DiscoveredDevice: Hashable, Equatable {
    var id = UUID()
    var device: ORESPDevice

    func hash(into hasher: inout Hasher) {
        hasher.combine(device.name)
    }

    static func ==(lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.device.name == rhs.device.name
    }

    var info: [String: Any] {
        [
            "id": id.uuidString,
            "name": device.name
        ]
    }
}

