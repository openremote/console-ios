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

@testable import ESPProvision
import Foundation
import Testing

@testable import ORLib

class ESPORProvisionManagerMock: ORESPProvisionManager {
    var searchESPDevicesCallCount = 0
    var stopESPDevicesSearchCallCount = 0

    var scanDevicesDuration: TimeInterval = 0

    var mockDevices = [ORESPDeviceMock()]

    func searchESPDevices(devicePrefix: String, transport: ESPTransport, security: ESPSecurity) async throws -> [ORESPDevice] {
        searchESPDevicesCallCount += 1
        if scanDevicesDuration > 0 {
            try await Task.sleep(nanoseconds: UInt64(scanDevicesDuration * Double(NSEC_PER_SEC)))
        }
        return mockDevices
    }
    
    func stopESPDevicesSearch() {
        stopESPDevicesSearchCallCount += 1
    }
}

struct ESPProvisionProviderTest {

    // MARK: device scan

    @Test func searchDeviceSuccess() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startDevicesScan()
        }

        // Even if I wait for a moment, if no new devices are discovered, I should only received the callback once
        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))

        #expect(espProvisionMock.searchESPDevicesCallCount >= 1)
        #expect(receivedCallbackCount == 1)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.startBleScan)

        #expect(receivedData["devices"] as? [[String:Any]] != nil)
        let devices = receivedData["devices"] as! [[String:Any]]
        #expect(devices.count == 1)
        let device = devices.first!
        #expect(device["name"] as? String == "TestDevice")
        #expect(device["id"] != nil)
    }

    @Test func searchDevicesMultipleBatches() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        var firstReceivedData: [String:Any] = [:]

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    firstReceivedData = data
                    espProvisionMock.mockDevices.append(ORESPDeviceMock(name: "TestDevice2"))
                    continuation.resume()
                }
            }
            provider.startDevicesScan()
        }

        // Need to wait a moment for second callback to be received
        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))

        #expect(espProvisionMock.searchESPDevicesCallCount >= 2)
        #expect(receivedCallbackCount == 2)

        #expect(firstReceivedData["provider"] as? String == Providers.espprovision)
        #expect(firstReceivedData["action"] as? String == Actions.startBleScan)

        #expect(firstReceivedData["devices"] as? [[String:Any]] != nil)
        var devices = firstReceivedData["devices"] as! [[String:Any]]
        #expect(devices.count == 1)
        let device = devices.first!
        #expect(device["name"] as? String == "TestDevice")
        #expect(device["id"] != nil)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.startBleScan)

        #expect(receivedData["devices"] as? [[String:Any]] != nil)
        devices = receivedData["devices"] as! [[String:Any]]
        #expect(devices.count == 2)

        #expect(devices.first!["name"] as? String == "TestDevice")
        #expect(devices.first!["id"] != nil)
        #expect(devices.last!["name"] as? String == "TestDevice2")
        #expect(devices.last!["id"] != nil)
    }

    @Test func testDisableStopsDeviceSearch() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        espProvisionMock.scanDevicesDuration = 0.5

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedDeviceInformation = false
        provider.startDevicesScan()
        #expect(provider.bleScanning)
        provider.sendDataCallback = { _ in
            receivedDeviceInformation = true
        }

        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))

        var receivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            provider.sendDataCallback = { data in
                receivedData = data
                continuation.resume()
            }
            _ = provider.disable()
        }

        #expect(espProvisionMock.stopESPDevicesSearchCallCount == 1)
        #expect(provider.bleScanning == false)
        #expect(receivedDeviceInformation == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)
        #expect(receivedData["devices"] == nil)
        #expect(receivedData.count == 2)
    }

    @Test func testStopDeviceSearch() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        espProvisionMock.scanDevicesDuration = 0.5

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedDeviceInformation = false
        provider.startDevicesScan()
        #expect(provider.bleScanning)
        provider.sendDataCallback = { _ in
            receivedDeviceInformation = true
        }

        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))

        var receivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.stopDevicesScan()
        }

        #expect(espProvisionMock.searchESPDevicesCallCount == 1)
        #expect(espProvisionMock.stopESPDevicesSearchCallCount == 1)
        #expect(receivedDeviceInformation == false)
        #expect(provider.bleScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)
        #expect((receivedData["devices"] as? [String:Any]) == nil)
        #expect(receivedData.count == 2)
    }

    @Test func testStopDeviceSearchNotStarted() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        espProvisionMock.scanDevicesDuration = 0.5

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.stopDevicesScan()
        }

        #expect(espProvisionMock.searchESPDevicesCallCount == 0)
        #expect(espProvisionMock.stopESPDevicesSearchCallCount == 1)
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)
        #expect((receivedData["devices"] as? [String:Any]) == nil)
        #expect(receivedData.count == 2)
        #expect(provider.bleScanning == false)
    }

    @Test func searchDevicesTimesout() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        espProvisionMock.mockDevices = []
        espProvisionMock.scanDevicesDuration = 0.05

        let provider = ESPProvisionProvider(searchDeviceTimeout: 0.2)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startDevicesScan()
            #expect(provider.bleScanning)
        }

        // Wait long enough so scan can stop
        try await Task.sleep(nanoseconds: UInt64(0.3 * Double(NSEC_PER_SEC)))

        // Ideally should be == 4 but too brittle based on timing during test run
        #expect(espProvisionMock.searchESPDevicesCallCount >= 2 && espProvisionMock.searchESPDevicesCallCount <= 4)
        #expect(receivedCallbackCount == 1)
        #expect(provider.bleScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.timeoutError.rawValue)
    }

    @Test func searchDevicesMaximumIteration() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        espProvisionMock.mockDevices = []
        espProvisionMock.scanDevicesDuration = 0.05

        let provider = ESPProvisionProvider(searchDeviceTimeout: 120, searchDeviceMaxIterations: 5)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startDevicesScan()
            #expect(provider.bleScanning)
        }

        // Wait long enough so scan can stop
        try await Task.sleep(nanoseconds: UInt64(0.3 * Double(NSEC_PER_SEC)))

        #expect(espProvisionMock.searchESPDevicesCallCount == 5)
        #expect(receivedCallbackCount == 1)
        #expect(provider.bleScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.timeoutError.rawValue)
    }

    // MARK: Device connection

    @Test func connectToDevice() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)
        #expect(provider.bleScanning)

        let receivedMessages = await waitForMessages(provider: provider, expectingActions: [Actions.stopBleScan, Actions.connectToDevice]) {
            provider.connectTo(deviceId: device["id"] as! String)
        }
        #expect(provider.bleScanning == false)

        #expect(espProvisionMock.stopESPDevicesSearchCallCount == 1)

        #expect(receivedMessages.count == 2)

        var receivedData = receivedMessages[0]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)

        receivedData = receivedMessages[1]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.connectToDevice)
        #expect(receivedData["id"] as? String == device["id"] as? String)
        #expect(receivedData["status"] as? String == ESPProviderConnectToDeviceStatus.connected)
    }

    @Test func connectToDeviceFailsForInvalidId() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        _ = await getDevice(provider: provider)
        #expect(provider.bleScanning)

        var receivedData: [String:Any] = [:]

        await withCheckedContinuation { continuation in
            provider.sendDataCallback = { data in
                if (data["action"] as? String) == Actions.connectToDevice {
                    receivedData = data
                    continuation.resume()
                }
            }
            provider.connectTo(deviceId: "INVALID_ID")
        }

        #expect(espProvisionMock.stopESPDevicesSearchCallCount == 1)
        #expect(provider.bleScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.connectToDevice)
        #expect(receivedData["status"] as? String == ESPProviderConnectToDeviceStatus.connectionError)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.unknownDevice.rawValue)
    }


    // TODO: test different connection failures
    // TODO: test disconnection (wanted or not)

    // TODO: start device scan after wifi search

    // MARK: Wifi scan

    @Test func startWifiScanNotConnected() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        _ = await getDevice(provider: provider)

        provider.stopDevicesScan()

        let receivedData = await waitForMessage(provider: provider, expectingAction: Actions.stopWifiScan) {
            provider.startWifiScan()
        }
        #expect(provider.wifiScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopWifiScan)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.notConnected.rawValue)
    }

    @Test func wifiScan() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)
        var receivedData: [String:Any] = [:]

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startWifiScan()
        }

        // Even if I wait for a moment, if no new devices are discovered, I should only received the callback once
        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))

        #expect(mockDevice.scanWifiListCallCount >= 1)
        #expect(provider.wifiScanning)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.startWifiScan)

        #expect(receivedData["networks"] as? [[String:Any]] != nil)
        let networks = receivedData["networks"] as! [[String:Any]]
        #expect(networks.count == 1)
        let network = networks.first!
        #expect(network["ssid"] as? String == "SSID-1")
        #expect(network["signalStrength"] as? Int32 == -50)
    }

    @Test func wifiScanUpdatedRssi() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        mockDevice.scanWifiDuration = 0.1
        mockDevice.networks = [ESPWifiNetwork(ssid: "SSID-1", rssi: -50)]
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)
        var receivedData: [String:Any] = [:]

        var firstReceivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    firstReceivedData = data
                    mockDevice.networks = [ESPWifiNetwork(ssid: "SSID-1", rssi: -60)]
                    continuation.resume()
                }
            }
            provider.startWifiScan()
        }

        // I need to wait a moment for the second callback to be received
        try await Task.sleep(nanoseconds: UInt64(0.2 * Double(NSEC_PER_SEC)))
        #expect(provider.wifiScanning)

        #expect(firstReceivedData["provider"] as? String == Providers.espprovision)
        #expect(firstReceivedData["action"] as? String == Actions.startWifiScan)

        #expect(firstReceivedData["networks"] as? [[String:Any]] != nil)
        let networks = firstReceivedData["networks"] as! [[String:Any]]
        #expect(networks.count == 1)
        let network = networks.first!
        #expect(network["ssid"] as? String == "SSID-1")
        #expect(network["signalStrength"] as? Int32 == -50)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.startWifiScan)

        #expect(receivedData["networks"] as? [[String:Any]] != nil)
        let networks2 = receivedData["networks"] as! [[String:Any]]
        #expect(networks2.count == 1)
        let network2 = networks2.first!
        #expect(network2["ssid"] as? String == "SSID-1")
        #expect(network2["signalStrength"] as? Int32 == -60)
    }

    @Test func wifiScanTimesout() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        mockDevice.scanWifiDuration = 0.05
        mockDevice.networks = []
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 0.2)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startWifiScan()
            #expect(provider.wifiScanning)
        }

        // Wait long enough so scan can stop
        try await Task.sleep(nanoseconds: UInt64(0.3 * Double(NSEC_PER_SEC)))

        // Ideally should be == 4 but too brittle based on timing during test run
        #expect(mockDevice.scanWifiListCallCount >= 2 && mockDevice.scanWifiListCallCount <= 4)
        #expect(receivedCallbackCount == 1)
        #expect(provider.wifiScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopWifiScan)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.timeoutError.rawValue)
    }

    @Test func wifiScanMaximumIterations() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        mockDevice.scanWifiDuration = 0.05
        mockDevice.networks = []
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 120, searchWifiMaxIterations: 5)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startWifiScan()
            #expect(provider.wifiScanning)
        }

        // Wait long enough so scan can stop
        try await Task.sleep(nanoseconds: UInt64(0.3 * Double(NSEC_PER_SEC)))

        #expect(mockDevice.scanWifiListCallCount == 5)
        #expect(receivedCallbackCount == 1)
        #expect(provider.wifiScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopWifiScan)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.timeoutError.rawValue)
    }

    @Test func testStopWifiScan() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        mockDevice.scanWifiDuration = 0.5
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedDeviceInformation = false
        provider.startWifiScan()
        #expect(provider.wifiScanning)
        provider.sendDataCallback = { _ in
            receivedDeviceInformation = true
        }
        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))

        var receivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.stopWifiScan()
        }
        #expect(mockDevice.scanWifiListCallCount == 1)
        // There's not scan stop operation of device, can't validate that
        #expect(receivedDeviceInformation == false)
        #expect(provider.wifiScanning == false)

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopWifiScan)
        #expect((receivedData["networks"] as? [String:Any]) == nil)
        #expect(receivedData.count == 2)
    }

    @Test func testStopWifiScanNotStarted() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        mockDevice.scanWifiDuration = 0.5
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedDeviceInformation = false
        provider.sendDataCallback = { _ in
            receivedDeviceInformation = true
        }
        provider.stopWifiScan()

        #expect(mockDevice.scanWifiListCallCount == 0)
        // There's not scan stop operation of device, can't validate that
        #expect(receivedDeviceInformation == false)
        #expect(provider.wifiScanning == false)
    }

    // TODO: connect to device during wifi search -> what's the expect behaviour for same device or different device
    // TODO: if connect to different device and restart a wifi scan, should receive potentially different list

    // TODO: start device scan during wifi search

    @Test func sendWifiConfigurationSuccess() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)
        var receivedData: [String:Any] = [:]

        
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startWifiScan()
        }
        #expect(provider.wifiScanning)

        let network = (receivedData["networks"] as! [[String:Any]]).first!

        let receivedMessages = await waitForMessages(provider: provider, expectingActions: [Actions.stopWifiScan, Actions.sendWifiConfiguration]) {
            provider.sendWifiConfiguration(ssid: network["ssid"] as? String ?? "", password: "s3cr3t")
        }

        #expect(receivedMessages.count == 2)

        receivedData = receivedMessages[0]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopWifiScan)
        #expect(receivedData.count == 2)

        receivedData = receivedMessages[1]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.sendWifiConfiguration)
        #expect(receivedData["connected"] as? Bool == true)

        #expect(mockDevice.provisionCalledCount == 1)
        #expect(mockDevice.provisionCalledParameters != nil)
        #expect(mockDevice.provisionCalledParameters!.0 == "SSID-1")
        #expect(mockDevice.provisionCalledParameters!.1 == "s3cr3t")
        #expect(provider.wifiScanning == false)
    }

    @Test(arguments: [
        (ESPProvisionError.sessionError, ESPProviderErrorCode.communicationError),
        (ESPProvisionError.configurationError(ESPProvisionError.unknownError), ESPProviderErrorCode.wifiConfigurationError),
        (ESPProvisionError.wifiStatusError(ESPProvisionError.unknownError), ESPProviderErrorCode.wifiConfigurationError),
        (ESPProvisionError.wifiStatusDisconnected, ESPProviderErrorCode.wifiConfigurationError),
        (ESPProvisionError.wifiStatusAuthenticationError, ESPProviderErrorCode.wifiAuthenticationError),
        (ESPProvisionError.wifiStatusNetworkNotFound, ESPProviderErrorCode.wifiNetworkNotFound),
        (ESPProvisionError.wifiStatusUnknownError, ESPProviderErrorCode.wifiCommunicationError),
        (ESPProvisionError.threadStatusError(ESPProvisionError.unknownError), ESPProviderErrorCode.genericError),
        (ESPProvisionError.threadStatusDettached, ESPProviderErrorCode.genericError),
        (ESPProvisionError.threadDatasetInvalid, ESPProviderErrorCode.genericError),
        (ESPProvisionError.threadStatusNetworkNotFound, ESPProviderErrorCode.genericError),
        (ESPProvisionError.threadStatusUnknownError, ESPProviderErrorCode.genericError),
        (ESPProvisionError.unknownError, ESPProviderErrorCode.genericError)
    ])
    func sendWifiConfigurationProvisionErrors(errorTupple: (ESPProvisionError, ESPProviderErrorCode)) async throws {
        let (provisionError, providerErrorCode) = errorTupple
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        mockDevice.provisionError = provisionError
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startWifiScan()
        }
        #expect(provider.wifiScanning)

        let network = (receivedData["networks"] as! [[String:Any]]).first!

        let receivedMessages = await waitForMessages(provider: provider, expectingActions: [Actions.stopWifiScan, Actions.sendWifiConfiguration]) {
            provider.sendWifiConfiguration(ssid: network["ssid"] as? String ?? "", password: "s3cr3t")
        }

        #expect(receivedMessages.count == 2)

        receivedData = receivedMessages[0]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopWifiScan)
        #expect(receivedData.count == 2)

        receivedData = receivedMessages[1]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.sendWifiConfiguration)
        #expect(receivedData["connected"] as? Bool != nil)
        #expect(receivedData["connected"] as? Bool == false)
        #expect(receivedData["errorCode"] as? Int == providerErrorCode.rawValue)

        #expect(mockDevice.provisionCalledCount == 1)
        #expect(mockDevice.provisionCalledParameters != nil)
        #expect(mockDevice.provisionCalledParameters!.0 == "SSID-1")
        #expect(mockDevice.provisionCalledParameters!.1 == "s3cr3t")
        #expect(provider.wifiScanning == false)
    }

    @Test func sendWifiConfigurationNotConnected() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        _ = await getDevice(provider: provider)

        provider.stopDevicesScan()

        let receivedData = await waitForMessage(provider: provider, expectingAction: Actions.sendWifiConfiguration) {
            provider.sendWifiConfiguration(ssid: "SSID-1", password: "s3cr3t")
        }

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.sendWifiConfiguration)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.notConnected.rawValue)
    }

    // MARK: Provision


    @Test func provisionDeviceSuccess() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()

        var expectedDeviceInfo = Response.DeviceInfo()
        expectedDeviceInfo.deviceID = "123456789ABC"
        expectedDeviceInfo.modelName = "My Battery"

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .success

        var expectedBackendConnectionStatus = Response.BackendConnectionStatus()
        expectedBackendConnectionStatus.status = .connected

        mockDevice.addMockData(ORConfigChannelTest.responseData(body: .deviceInfo(expectedDeviceInfo)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "1", body: .openRemoteConfig(expectedOpenRemoteConfig)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "2", body: .backendConnectionStatus(expectedBackendConnectionStatus)))
        espProvisionMock.mockDevices = [mockDevice]

        let batteryProvisionAPIMock = BatteryProvisionAPIMock()
        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max,
                                            searchWifiTimeout: 1, searchWifiMaxIterations: Int.max,
                                            batteryProvisionAPI: batteryProvisionAPIMock)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.provisionDevice(userToken: "OAUTH_TOKEN")
        }

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.provisionDevice)
        #expect(receivedData["connected"] as? Bool == true)

        #expect(mockDevice.receivedData.count == 3)

        var request = try Request(serializedBytes: mockDevice.receivedData[0])
        #expect(request.id == "0")
        #expect(request.body == .deviceInfo(Request.DeviceInfo()))

        request = try Request(serializedBytes: mockDevice.receivedData[1])
        #expect(request.id == "1")
        if case let .openRemoteConfig(openRemoteConfig) = request.body {
            #expect(openRemoteConfig.realm == "master")
            #expect(openRemoteConfig.mqttBrokerURL == "mqtts://localhost:8883")
            #expect(openRemoteConfig.user == expectedDeviceInfo.deviceID.lowercased(with: Locale(identifier: "en")))
            #expect(openRemoteConfig.mqttPassword != nil)
            #expect(openRemoteConfig.mqttPassword == batteryProvisionAPIMock.receivedPassword)
            #expect(openRemoteConfig.assetID == "AssetID")

        } else {
            Issue.record("Received an unexpected response: \(request)")
        }

        request = try Request(serializedBytes: mockDevice.receivedData[2])
        #expect(request.id == "2")
        #expect(request.body == .backendConnectionStatus(Request.BackendConnectionStatus()))

        #expect(batteryProvisionAPIMock.provisionCallCount == 1)
        #expect(batteryProvisionAPIMock.receivedDeviceId == expectedDeviceInfo.deviceID)
        #expect(batteryProvisionAPIMock.receivedPassword != nil)
        #expect(batteryProvisionAPIMock.receivedToken == "OAUTH_TOKEN")
    }

    @Test func provisionDeviceSuccessAfterMultipleStatusRequest() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()

        var expectedDeviceInfo = Response.DeviceInfo()
        expectedDeviceInfo.deviceID = "123456789ABC"
        expectedDeviceInfo.modelName = "My Battery"

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .success

        var expectedBackendConnectionStatusSuccess = Response.BackendConnectionStatus()
        expectedBackendConnectionStatusSuccess.status = .connected

        var expectedBackendConnectionStatusFailure = Response.BackendConnectionStatus()
        expectedBackendConnectionStatusFailure.status = .disconnected

        mockDevice.addMockData(ORConfigChannelTest.responseData(body: .deviceInfo(expectedDeviceInfo)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "1", body: .openRemoteConfig(expectedOpenRemoteConfig)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "2", body: .backendConnectionStatus(expectedBackendConnectionStatusFailure)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "3", body: .backendConnectionStatus(expectedBackendConnectionStatusFailure)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "4", body: .backendConnectionStatus(expectedBackendConnectionStatusSuccess)))
        espProvisionMock.mockDevices = [mockDevice]

        let batteryProvisionAPIMock = BatteryProvisionAPIMock()
        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max,
                                            searchWifiTimeout: 1, searchWifiMaxIterations: Int.max,
                                            batteryProvisionAPI: batteryProvisionAPIMock)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.provisionDevice(userToken: "OAUTH_TOKEN")
        }

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.provisionDevice)
        #expect(receivedData["connected"] as? Bool == true)

        try #require(mockDevice.receivedData.count == 5)

        var request = try Request(serializedBytes: mockDevice.receivedData[0])
        #expect(request.id == "0")
        #expect(request.body == .deviceInfo(Request.DeviceInfo()))

        request = try Request(serializedBytes: mockDevice.receivedData[1])
        #expect(request.id == "1")
        if case let .openRemoteConfig(openRemoteConfig) = request.body {
            #expect(openRemoteConfig.realm == "master")
            #expect(openRemoteConfig.mqttBrokerURL == "mqtts://localhost:8883")
            #expect(openRemoteConfig.user == expectedDeviceInfo.deviceID.lowercased(with: Locale(identifier: "en")))
            #expect(openRemoteConfig.mqttPassword != nil)
            #expect(openRemoteConfig.mqttPassword == batteryProvisionAPIMock.receivedPassword)
            #expect(openRemoteConfig.assetID == "AssetID")

        } else {
            Issue.record("Received an unexpected response: \(request)")
        }

        for i in 2...4 {
            request = try Request(serializedBytes: mockDevice.receivedData[i])
            #expect(request.id == String(i))
            #expect(request.body == .backendConnectionStatus(Request.BackendConnectionStatus()))
        }

        #expect(batteryProvisionAPIMock.provisionCallCount == 1)
        #expect(batteryProvisionAPIMock.receivedDeviceId == expectedDeviceInfo.deviceID)
        #expect(batteryProvisionAPIMock.receivedPassword != nil)
        #expect(batteryProvisionAPIMock.receivedToken == "OAUTH_TOKEN")
    }

    @Test func provisionDeviceFailureTimeout() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()

        var expectedDeviceInfo = Response.DeviceInfo()
        expectedDeviceInfo.deviceID = "123456789ABC"
        expectedDeviceInfo.modelName = "My Battery"

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .success

        var expectedBackendConnectionStatusFailure = Response.BackendConnectionStatus()
        expectedBackendConnectionStatusFailure.status = .disconnected

        mockDevice.addMockData(ORConfigChannelTest.responseData(body: .deviceInfo(expectedDeviceInfo)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "1", body: .openRemoteConfig(expectedOpenRemoteConfig)))
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "2", body: .backendConnectionStatus(expectedBackendConnectionStatusFailure)), delay: 0.2)
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "3", body: .backendConnectionStatus(expectedBackendConnectionStatusFailure)), delay: 0.2)
        mockDevice.addMockData(ORConfigChannelTest.responseData(id: "4", body: .backendConnectionStatus(expectedBackendConnectionStatusFailure)), delay: 0.2)
        espProvisionMock.mockDevices = [mockDevice]

        let batteryProvisionAPIMock = BatteryProvisionAPIMock()
        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max,
                                            searchWifiTimeout: 1, searchWifiMaxIterations: Int.max,
                                            batteryProvisionAPI: batteryProvisionAPIMock, backendConnectionTimeout: 0.5)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        let device = await getDevice(provider: provider)

        try await connectToDevice(provider: provider, deviceId: device["id"] as! String)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.provisionDevice(userToken: "OAUTH_TOKEN")
        }

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.provisionDevice)
        #expect(receivedData["connected"] as? Bool != nil)
        #expect(receivedData["connected"] as? Bool == false)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.timeoutError.rawValue)

        try #require(mockDevice.receivedData.count == 5)

        var request = try Request(serializedBytes: mockDevice.receivedData[0])
        #expect(request.id == "0")
        #expect(request.body == .deviceInfo(Request.DeviceInfo()))

        request = try Request(serializedBytes: mockDevice.receivedData[1])
        #expect(request.id == "1")
        if case let .openRemoteConfig(openRemoteConfig) = request.body {
            #expect(openRemoteConfig.realm == "master")
            #expect(openRemoteConfig.mqttBrokerURL == "mqtts://localhost:8883")
            #expect(openRemoteConfig.user == expectedDeviceInfo.deviceID.lowercased(with: Locale(identifier: "en")))
            #expect(openRemoteConfig.mqttPassword != nil)
            #expect(openRemoteConfig.mqttPassword == batteryProvisionAPIMock.receivedPassword)
            #expect(openRemoteConfig.assetID == "AssetID")

        } else {
            Issue.record("Received an unexpected response: \(request)")
        }

        for i in 2...4 {
            request = try Request(serializedBytes: mockDevice.receivedData[i])
            #expect(request.id == String(i))
            #expect(request.body == .backendConnectionStatus(Request.BackendConnectionStatus()))
        }

        #expect(batteryProvisionAPIMock.provisionCallCount == 1)
        #expect(batteryProvisionAPIMock.receivedDeviceId == expectedDeviceInfo.deviceID)
        #expect(batteryProvisionAPIMock.receivedPassword != nil)
        #expect(batteryProvisionAPIMock.receivedToken == "OAUTH_TOKEN")
    }

    @Test func provisionDeviceNotConnected() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()
        let mockDevice = ORESPDeviceMock()
        espProvisionMock.mockDevices = [mockDevice]

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        _ = await getDevice(provider: provider)

        var receivedData: [String:Any] = [:]
        var receivedCallbackCount = 0

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                receivedCallbackCount += 1
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }
            provider.provisionDevice(userToken: "OAUTH_TOKEN")
        }

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.provisionDevice)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.notConnected.rawValue)
    }

    // MARK: Exit provisioning

    @Test func exitProvisioningNotConnected() async throws {
        let espProvisionMock = ESPORProvisionManagerMock()

        let provider = ESPProvisionProvider(searchDeviceTimeout: 1, searchDeviceMaxIterations: Int.max, searchWifiTimeout: 1, searchWifiMaxIterations: Int.max)
        _ = provider.initialize()
        _ = provider.enable()
        provider.setProvisionManager(espProvisionMock)

        _ = await getDevice(provider: provider)

        provider.stopDevicesScan()

        let receivedData = await waitForMessage(provider: provider, expectingAction: Actions.exitProvisioning) {
            provider.exitProvisioning()
        }

        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.exitProvisioning)
        #expect(receivedData["errorCode"] as? Int == ESPProviderErrorCode.notConnected.rawValue)
    }

    // MARK: helpers

    private func getDevice(provider: ESPProvisionProvider) async -> [String: Any] {
        var receivedData: [String:Any] = [:]

        await withCheckedContinuation { continuation in
            var continuationCalled = false
            provider.sendDataCallback = { data in
                receivedData = data
                if !continuationCalled {
                    continuationCalled = true
                    continuation.resume()
                }
            }

            provider.startDevicesScan()
        }

        return (receivedData["devices"] as! [[String:Any]]).first!
    }

    private func connectToDevice(provider: ESPProvisionProvider, deviceId: String) async throws {
        var receivedMessages = await waitForMessages(provider: provider, expectingActions: [Actions.stopBleScan, Actions.connectToDevice]) {
            provider.connectTo(deviceId: deviceId)
        }

        #expect(receivedMessages.count == 2)

        let receivedData = receivedMessages[0]
        #expect(receivedData["provider"] as? String == Providers.espprovision)
        #expect(receivedData["action"] as? String == Actions.stopBleScan)
        #expect(receivedData.count == 2)
    }

    private func waitForMessage(provider: ESPProvisionProvider, expectingAction action: String, afterCalling trigger: (() -> (Void))) async -> [String:Any] {
        var receivedData: [String:Any] = [:]
        await withCheckedContinuation { continuation in
            provider.sendDataCallback = { data in
                if (data["action"] as? String) == action {
                    receivedData = data
                    continuation.resume()
                } else {
                    Issue.record("Received an unexpected action: \(data)")
                }
            }
            trigger()
        }
        return receivedData
    }

    private func waitForMessages(provider: ESPProvisionProvider, expectingActions actions: [String], afterCalling trigger: (() -> (Void))) async -> [[String:Any]] {
        var receivedData: [[String:Any]] = []
        var actionsIterator = actions.makeIterator()
        var expectedAction = actionsIterator.next()
        await withCheckedContinuation { continuation in
            provider.sendDataCallback = { data in
                if (data["action"] as? String) == expectedAction {
                    receivedData.append(data)
                    expectedAction = actionsIterator.next()
                    if expectedAction == nil {
                        continuation.resume()
                    }
                } else {
                    Issue.record("Received an unexpected action: \(data)")
                }
            }
            trigger()
        }
        return receivedData
    }
}
