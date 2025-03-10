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
import os

typealias SendDataCallback = ([String: Any]) -> (Void)

class ESPProvisionProvider: NSObject {
    private static let logger = Logger(
           subsystem: Bundle.main.bundleIdentifier!,
           category: String(describing: ESPProvisionProvider.self)
       )
    public static let espProvisionDisabledKey = "espProvisionDisabled"

    let userdefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement)
    let version = "beta"



    private var deviceRegistry = DeviceRegistry()

    private var deviceConnection: DeviceConnection?

    private var wifiProvisioner: WifiProvisioner?

    var sendDataCallback: SendDataCallback? {
        didSet {
            deviceRegistry.sendDataCallback = sendDataCallback
            deviceConnection?.sendDataCallback = sendDataCallback
        }
    }

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

    public func enable() -> [String: Any] {
        deviceRegistry.enable()

        userdefaults?.removeObject(forKey: ESPProvisionProvider.espProvisionDisabledKey)
        userdefaults?.synchronize()

        return [
            DefaultsKey.actionKey: Actions.providerEnable,
            DefaultsKey.providerKey: Providers.espprovision,
            DefaultsKey.hasPermissionKey: CBCentralManager.authorization == .allowedAlways,
            DefaultsKey.successKey: true
        ]
    }

    public func disable() -> [String: Any] {
        deviceRegistry.disable()

        disconnectFromDevice()
        // This eventually calls ESPBLEDelegate.peripheralDisconnected that sets device, deviceId and configChannel to nil

        userdefaults?.set(true, forKey: ESPProvisionProvider.espProvisionDisabledKey)
        userdefaults?.synchronize()
        return [
            DefaultsKey.actionKey: Actions.providerDisable,
            DefaultsKey.providerKey: Providers.espprovision
        ]
    }

    // MARK: Device scan

    public func startDevicesScan(prefix: String? = nil) {
        deviceRegistry.startDevicesScan(prefix: prefix)
    }

    public func stopDevicesScan() {
        deviceRegistry.stopDevicesScan()
    }

    // MARK: Device connect/disconnect

    public func connectTo(deviceId idToConnectTo: String, pop: String? = nil, username: String? = nil) {
        if deviceConnection == nil {
            deviceConnection = DeviceConnection(deviceRegistry: deviceRegistry, sendDataCallback: sendDataCallback)
        }
        deviceConnection!.connectTo(deviceId: idToConnectTo, pop: pop, username: username)
    }

    public func disconnectFromDevice() {
        wifiProvisioner?.stopWifiScan()
        deviceConnection?.disconnectFromDevice()
    }

    public func exitProvisioning() {
        guard deviceConnection?.isConnected ?? false else {
            sendExitProvisioningError(.notConnected, errorMessage: "No connection established to device")
            return
        }
        deviceConnection!.exitProvisioning()
    }

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

    // MARK: Wifi scan

    public func startWifiScan() {
        if wifiProvisioner == nil {
            wifiProvisioner = WifiProvisioner(deviceConnection: deviceConnection, sendDataCallback: sendDataCallback)
        }
        wifiProvisioner!.startWifiScan()
    }

    public func stopWifiScan() {
        wifiProvisioner?.stopWifiScan()
    }

    public func sendWifiConfiguration(ssid: String, password: String) {
        wifiProvisioner?.sendWifiConfiguration(ssid: ssid, password: password)
    }

    // MARK: OR Configuration


}


#if DEBUG
// TODO: see https://stackoverflow.com/a/60267724 for improvement
extension ESPProvisionProvider {
    func setProvisionManager(_ provisionManager: ORESPProvisionManager) {
        self.deviceRegistry.provisionManager = provisionManager
    }
}
#endif

public enum ESPProviderError: Int {
    case unknownDevice = 100

    case bleCommunicationError = 200

    case notConnected = 300
    case communicationError = 301

    case securityError = 400

    case wifiConfigurationError = 500
    case wifiCommunicationError = 501
    case wifiAuthenticationError = 502
    case wifiNetworkNotFound = 503


    case genericError = 10000
}

public enum ESPProviderConnectToDeviceStatus {
    public static let connected = "connected"
    public static let disconnected = "disconnected"
    public static let connectionError = "connectionError"
}
