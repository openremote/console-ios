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

struct MockResponse {
    var mockData: Data?
    var mockError: ESPSessionError?
    var delay: TimeInterval

    init(mockData: Data? = nil, mockError: ESPSessionError? = nil, delay: TimeInterval = 0) {
        self.mockData = mockData
        self.mockError = mockError
        self.delay = delay
    }
}

class ORESPDeviceMock: ORESPDevice {

    private var mockResponses: [MockResponse] = []
    private var mockResponsesIndex: [MockResponse].Index? = nil

    var scanWifiListCallCount = 0
    var scanWifiDuration: TimeInterval = 0
    var networks = [ESPWifiNetwork(ssid: "SSID-1", rssi: -50)]

    var provisionError: ESPProvisionError?
    var provisionCalledCount = 0
    var provisionCalledParameters: (String?, String?)?

    var receivedData: [Data] = []

    init(name: String) {
        self.name = name
    }

    convenience init() {
        self.init(name: "TestDevice")
    }

    var bleDelegate: (any ESPBLEDelegate)?

    var name: String

    func resetMockResponses() {
        mockResponses = []
        mockResponsesIndex = nil
    }

    func addMockData(_ data: Data, delay: TimeInterval = 0) {
        mockResponses.append(MockResponse(mockData: data, delay: delay))
    }

    func addMockError(_ error: ESPSessionError, delay: TimeInterval = 0) {
        mockResponses.append(MockResponse(mockError: error, delay: delay))
    }

    func connect(delegate: (any ESPDeviceConnectionDelegate)?, completionHandler: @escaping (ESPSessionStatus) -> Void) {
        // TODO: instrument so can set the status to return
        completionHandler(.connected)
    }

    func disconnect() {
        // TODO: could have a counter here ?
        print("device - disconnect")

    }

    func scanWifiList(completionHandler: @escaping ([ESPWifiNetwork]?, ESPWiFiScanError?) -> Void) {
        scanWifiListCallCount += 1
        Task {
            if scanWifiDuration > 0 {
                try await Task.sleep(nanoseconds: UInt64(scanWifiDuration * Double(NSEC_PER_SEC)))
            }
            completionHandler(networks, nil)
        }
    }

    func provision(ssid: String?, passPhrase: String?, threadOperationalDataset: Data?, completionHandler: @escaping (ESPProvisionStatus) -> Void) {
        provisionCalledCount += 1
        provisionCalledParameters = (ssid, passPhrase)
        if let provisionError {
            completionHandler(.failure(provisionError))
        } else {
            completionHandler(.configApplied)
            completionHandler(.success)
        }
    }

    func sendData(path: String, data: Data, completionHandler: @escaping (Data?, ESPSessionError?) -> Void) {
        receivedData.append(data)
        let response = getNextMockResponse()
        guard let response else {
            completionHandler(nil, nil)
            return
        }
        Task {
            if response.delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(response.delay * Double(NSEC_PER_SEC)))
            }
            completionHandler(response.mockData, response.mockError)
        }
    }

    private func getNextMockResponse() -> MockResponse? {
        if mockResponses.isEmpty {
            return nil
        } else {
            if mockResponsesIndex != nil {
                mockResponsesIndex = mockResponses.index(after: mockResponsesIndex!)
                if mockResponsesIndex! >= mockResponses.endIndex {
                    mockResponsesIndex = mockResponses.startIndex
                    return mockResponses[mockResponsesIndex!]
                } else {
                    return mockResponses[mockResponsesIndex!]
                }
            } else {
                mockResponsesIndex = mockResponses.startIndex
                return mockResponses[mockResponsesIndex!]
            }
        }

    }
}
