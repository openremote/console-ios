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
import CoreBluetooth
import ESPProvision

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


// TODO: add logger

class ESPProvisionProvider: NSObject {
    public static let espProvisionDisabledKey = "espProvisionDisabled"

    let userdefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement)
    let version = "beta"

    typealias SendDataCallback = ([String: Any]) -> (Void)

    private var provisionManager: ORESPProvisionManager?

    private var prefix = "PROV_" // TODO: how should this be configured
    private var username = "wifiprov"
    private var pop = "abcd1234"

    private var devices: [DiscoveredDevice] = []
    private var devicesIndex: [UUID:DiscoveredDevice] = [:]

    private var bleScanning = false
    private var bleStatus = BLEStatus.disconnected

    // TODO: should this be reset on disconnect ?
    private var deviceId: UUID?
    private var device: ORESPDevice?

    private var wifiScanning = false
    private var wifiNetworks = [ESPWifiNetwork]()

    var sendDataCallback: SendDataCallback?

    public override init() {
        super.init()
    }

    // MARK: Standard provider lifecycle

    public func initialize() -> [String: Any] {
        return [
            DefaultsKey.actionKey: Actions.providerInit,
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.versionKey: version,
            DefaultsKey.requiresPermissionKey: true,
            DefaultsKey.hasPermissionKey: CBCentralManager.authorization == .allowedAlways,
            DefaultsKey.successKey: true,
            DefaultsKey.enabledKey: false,
            DefaultsKey.disabledKey: userdefaults?.bool(forKey: ESPProvisionProvider.espProvisionDisabledKey) ?? false
            // Question: this was BleProvider.bluetoothDisabledKey -> translates to bluetoothDisabled key -> is this the provider or BLE
        ]
    }

    public func enable(callback:@escaping ([String: Any]) -> (Void)) {
        userdefaults?.removeObject(forKey: ESPProvisionProvider.espProvisionDisabledKey)
        userdefaults?.synchronize()
        provisionManager = EspressifProvisionManager(provisionManager: ESPProvisionManager.shared)
        callback([
            DefaultsKey.actionKey: Actions.providerEnable,
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.hasPermissionKey: CBCentralManager.authorization == .allowedAlways,
            DefaultsKey.successKey: true
        ])
    }

    public func disable() -> [String: Any] {
        if bleScanning {
            provisionManager?.stopESPDevicesSearch()
        }
        provisionManager = nil

        // TODO: should we disconnect ?

        userdefaults?.set(true, forKey: ESPProvisionProvider.espProvisionDisabledKey)
        userdefaults?.synchronize()
        return [
            DefaultsKey.actionKey: Actions.providerDisable,
            DefaultsKey.providerKey: Providers.espprovision
        ]
    }

    // MARK: Device scan

    public func startDevicesScan() {
        bleScanning = true
        devices = []
        devicesScan()
    }

    public func stopDevicesScan() {
        bleScanning = false
        provisionManager?.stopESPDevicesSearch()
    }

    private func devicesScan() {
        if let provisionManager {
            Task {
                do {
                    let deviceList = try await provisionManager.searchESPDevices(devicePrefix:prefix, transport:.ble, security:.secure)

                    for device in deviceList {

                        // We need to assign an id to each device, so web app can refer to it
                        // TODO: but we consider name unique anyway and filter duplicates, so is id really useful ?
                        if self.devices.first(where: { $0.device.name == device.name }) == nil {
                            let dev = DiscoveredDevice(device: device)
                            self.devices.append(dev)
                            self.devicesIndex[dev.id] = dev
                        }
                    }
                    // If there are devices in the list, we communicated to web app
                    // TODO: we could optimize and check if changes since the last time
                    if !self.devices.isEmpty {
                        self.sendDataCallback?([
                            DefaultsKey.actionKey: Actions.startBleScan,
                            DefaultsKey.providerKey: Providers.espprovision,
                            DefaultsKey.dataKey: ["devices": self.devices.map { $0.info }] // TODO: check format that's output
                        ])
                        //Provider sent us ["data": ["devices": [["name": "PROV_335440", "id": "8ECEAD18-FAB8-49B0-B30D-930CA7B938B5"]]], "action": "START_BLE_SCAN", "provider": "espprovision"]
                        // TODO: is this the expected format or do we expect JSON ?

                    }
                } catch {
                    print(error.localizedDescription)
                    // The only error applicable to us here is espDeviceNotFound, we don't care about it
                }

                // Until app tells us to stop scanning, we repeat
                if self.bleScanning {
                    self.devicesScan()
                }
            }
        }
    }

    // MARK: Device connect/disconnect

    public func connectTo(deviceId idToConnectTo: String) {
        //TODO: what's the message to be sent here, a reply to connect or a general connection status message ?

//        BLE - connected is received sooner
//        "Connection status connected" call back from connect call arrives later

// For disconnection,



        if self.bleScanning {
            stopDevicesScan()
        }
        if let devId = UUID(uuidString: idToConnectTo), let dev = devicesIndex[devId] {
            device = dev.device
            deviceId = devId
            device!.bleDelegate = self
            device!.connect(delegate: self) { status in
                print("Connection status \(status)")
                switch status {
                case .connected:
                    self.bleStatus = .connected
                    self.sendConnectToDeviceStatus(status: "connected")
                    break
                case .failedToConnect(let error):
                    self.bleStatus = .disconnected
                    self.bleScanning = false
                    self.sendConnectToDeviceStatus(status: "connectionError", error: error.localizedDescription)
                case .disconnected:
                    self.bleStatus = .disconnected
                    self.bleScanning = false
                    self.sendConnectToDeviceStatus(status: "disconnected")
                    break
                }
            }
        }
    }

    public func disconnectFromDevice() {
        if let device {
            device.disconnect()
        }
    }

    private func sendConnectToDeviceStatus(status: String, error: String? = nil) {
        var data: [String: Any] = ["id": deviceId?.uuidString ?? "N/A", "status": status]
        if let error {
            data["error"] = error
        }
        self.sendDataCallback?([
            DefaultsKey.actionKey: Actions.connectToDevice,
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.dataKey: data
        ])
    }

    // MARK: Wifi scan

    public func startWifiScan() {
        wifiScanning = true
        scanWifi()
    }

    public func stopWifiScan() {
        wifiScanning = false
    }

    private func scanWifi() {
        device?.scanWifiList { wifiList, error in
            if let wifiList {
                for network in wifiList {
                    if self.wifiNetworks.first(where: { $0.ssid == network.ssid }) == nil {
                        self.wifiNetworks.append(network)
                    }
                }
                if !self.wifiNetworks.isEmpty && self.wifiScanning {
                    self.sendDataCallback?([
                        DefaultsKey.actionKey: Actions.startWifiScan,
                        DefaultsKey.providerKey: Providers.espprovision,
                        DefaultsKey.dataKey: ["networks": self.wifiNetworks
                            .map { ["ssid": $0.ssid, "signalStrength": $0.rssi] } ]
                        ])
                }
            } else {
                // TODO: what to do with this error ?
                // ESPWiFiScanError
                // It could be list is empty but also a real error, in later case, should be communicated to web app
                print(error)
            }
            if self.wifiScanning {
                self.scanWifi()
            }
        }
    }

    public func sendWifiConfiguration(ssid: String, password: String) {
        wifiScanning = false
        device?.provision(ssid: ssid, passPhrase: password, threadOperationalDataset: nil) { status in
            print("provision callback with status \(status)")
            // This block gets called multiple times
            // provision callback with status configApplied
            // then
            // provision callback with status failure(ESPProvision.ESPProvisionError.wifiStatusAuthenticationError)
            // or
            // provision callback with status success
            switch status {
            case .success:
                self.sendWifiConfigurationStatus(connected: true)
            case .failure(let error):
                self.sendWifiConfigurationStatus(connected: false, error: error.localizedDescription)
            case .configApplied:
                // This is an intermediate information we're not interested in forwarding
                break
            }
        }
    }

    private func sendWifiConfigurationStatus(connected: Bool, error: String? = nil) {
        var data: [String: Any] = ["connected": connected]
        if let error {
            data["error"] = error
        }
        self.sendDataCallback?([
            DefaultsKey.actionKey: Actions.sendWifiConfiguration,
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.dataKey: data
        ])
    }
}


extension ESPProvisionProvider: ESPBLEDelegate {
    func peripheralConnected() {
        bleStatus = .connected
    }

    func peripheralDisconnected(peripheral: CBPeripheral, error: Error?) {
        bleStatus = .disconnected
        // Careful about deviceId being reset or not at this stage
        self.sendConnectToDeviceStatus(status: "disconnected")
    }

    func peripheralFailedToConnect(peripheral: CBPeripheral?, error: Error?) {
        bleStatus = .disconnected
    }
}

extension ESPProvisionProvider: ESPDeviceConnectionDelegate {
    func getProofOfPossesion(forDevice: ESPDevice, completionHandler: @escaping (String) -> Void) {
        print("Asked for PoP")
        completionHandler(self.pop)
    }

    func getUsername(forDevice: ESPDevice, completionHandler: @escaping (String?) -> Void) {
        print("Asked for username")
        completionHandler(self.username)
    }
}

private enum BLEStatus {
    case connecting
    case connected
    case disconnected
}

private struct DiscoveredDevice: Hashable, Equatable {
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

#if DEBUG
// TODO: see https://stackoverflow.com/a/60267724 for improvement
extension ESPProvisionProvider {
    func setProvisionManager(_ provisionManager: ORESPProvisionManager) {
        self.provisionManager = provisionManager
    }
}
#endif
