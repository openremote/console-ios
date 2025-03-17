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


    public func searchESPDevices(devicePrefix: String, transport: ESPTransport, security: ESPSecurity = .secure) async throws -> [ORESPDevice] {
        return try await withCheckedThrowingContinuation { continuation in
            // We want to protect ourself against multiple resume of the continuation
            // This happened because searchESPDevices would call its callback a second time with an error when explicitly stopping the device search
            // even after the search has already completed with a list of device
            var alreadyResumed = false

            provisionManager.searchESPDevices(devicePrefix: devicePrefix, transport: transport, security: security) { deviceList, error in
                if let error {
                    if !alreadyResumed {
                        alreadyResumed = true
                        continuation.resume(throwing: error)
                    }
                } else {
                    alreadyResumed = true
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

    var callbackChannel: CallbackChannel?

    private var loopDetector: LoopDetector
    var searchDeviceTimeout: TimeInterval {
        get {
            loopDetector.timeout
        }
        set {
            self.loopDetector = LoopDetector(timeout: newValue, maxIterations: searchDeviceMaxIterations)
        }

    }
    var searchDeviceMaxIterations: Int {
        get {
            loopDetector.maxIterations
        }
        set {
            self.loopDetector = LoopDetector(timeout: searchDeviceTimeout, maxIterations: newValue)
        }

    }

    private var devices: [DiscoveredDevice] = []
    private var devicesIndex: [UUID:DiscoveredDevice] = [:]

    // TODO: check if here or some place else or how to be set ?
    var provisionManager: ORESPProvisionManager?

    public private(set) var bleScanning = false

    init(searchDeviceTimeout: TimeInterval, searchDeviceMaxIterations: Int) {
        self.loopDetector = LoopDetector(timeout: searchDeviceTimeout, maxIterations: searchDeviceMaxIterations)
    }

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
        loopDetector.reset()
        devicesScan(prefix: prefix ?? "")
    }

    public func stopDevicesScan(sendMessage: Bool = true) {
        bleScanning = false
        provisionManager?.stopESPDevicesSearch()
        if sendMessage {
            callbackChannel?.sendMessage(action: Actions.stopBleScan, data: nil)
        }
    }

    private func devicesScan(prefix: String) {
        if let provisionManager {
            Task {
                do {
                    if loopDetector.detectLoop() {
                        self.stopDevicesScan(sendMessage: false)
                        sendDeviceScanError(ESPProviderErrorCode.timeoutError)
                        return
                    }
                    Self.logger.trace("devicesScan will searchESPDevices")
                    let deviceList = try await provisionManager.searchESPDevices(devicePrefix: prefix, transport: .ble, security: .secure)
                    Self.logger.trace("devicesScan return from searchESPDevices")

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
                            callbackChannel?.sendMessage(action: Actions.startBleScan, data: ["devices": self.devices.map(\.info)])
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
                        } else { sendDeviceScanError(ESPProviderErrorCode.genericError) }
                    } else { sendDeviceScanError(ESPProviderErrorCode.genericError) }

                    // TODO: seems we can't have BLE permissions error here, but want to test

                }
            }
        }
    }

    private func sendDeviceScanError(_ error: ESPProviderErrorCode, errorMessage: String? = nil) {
        var data: [String: Any] = ["errorCode": error.rawValue]
        if let errorMessage {
            data["errorMessage"] = errorMessage
        }
        callbackChannel?.sendMessage(action: Actions.stopBleScan, data: data)
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

