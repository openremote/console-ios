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
import Testing

@testable import ORLib

struct ORConfigChannelTest {

    let deviceMock = ORESPDeviceMock()

    // MARK: General

    @Test func messageIdIncrement() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        deviceMock.addMockData(Self.responseData())
        _ = try await channel.publicSendRequest(deviceInfoRequest)
        #expect(channel.messageId == 1)

        deviceMock.resetMockResponses()
        deviceMock.addMockData(Self.responseData(id: "1"))
        _ = try await channel.publicSendRequest(deviceInfoRequest)
        #expect(channel.messageId == 2)
    }

    @Test func validResponse() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())
        deviceMock.addMockData(Self.responseData())

        _ = try await channel.publicSendRequest(deviceInfoRequest)
    }

    @Test func responseOutOfOrder() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        deviceMock.addMockData(Self.responseData(id: "10"))

        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        await #expect(throws: ORConfigChannelError.messageOutOfOrder) {
            _ = try await channel.publicSendRequest(deviceInfoRequest)
        }
    }

    @Test func noResponseData() async throws {
        var channel = ORConfigChannel(device: deviceMock)
        
        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        await #expect(throws: ORConfigChannelError.invalidResponse("No response received")) {
            _ = try await channel.publicSendRequest(deviceInfoRequest)
        }
    }

    @Test func invalidResponseData() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        deviceMock.addMockData("invalid".data(using: .utf8)!)

        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        await #expect(throws: ORConfigChannelError.invalidResponse("The operation couldn’t be completed. (SwiftProtobuf.BinaryDecodingError error 1.)")) {
            _ = try await channel.publicSendRequest(deviceInfoRequest)
        }
    }

    @Test func responseHasNoResult() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var response = Response()
        response.id = "0"
        deviceMock.addMockData(try! response.serializedBytes())

        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        await #expect(throws: ORConfigChannelError.invalidResponse("Response has no result")) {
            _ = try await channel.publicSendRequest(deviceInfoRequest)
        }
    }

    @Test func responseHasErrorResult() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        deviceMock.addMockData(Self.responseData(id: "0", result: .internalError))

        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        await #expect(throws: ORConfigChannelError.invalidResponse("Response result is internalError")) {
            _ = try await channel.publicSendRequest(deviceInfoRequest)
        }
    }

    // MARK: GetDeviceInfo

    @Test func validGetDeviceInfo() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedDeviceInfo = Response.DeviceInfo()
        expectedDeviceInfo.deviceID = "123456789ABC"
        expectedDeviceInfo.modelName = "My Battery"
        deviceMock.addMockData(Self.responseData(body: .deviceInfo(expectedDeviceInfo)))

        let deviceInfo = try await channel.getDeviceInfo()
        #expect(deviceInfo.deviceId == expectedDeviceInfo.deviceID)
        #expect(deviceInfo.modelName == expectedDeviceInfo.modelName)
    }

    @Test func getDeviceInfoWrongResponseType() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .success
        deviceMock.addMockData(Self.responseData(body: .openRemoteConfig(expectedOpenRemoteConfig)))

        await #expect(throws: ORConfigChannelError.invalidResponse("Invalid response type")) {
            _ = try await channel.getDeviceInfo()
        }
    }

    // MARK: SendOpenRemoteConfig

    @Test func validSendOpenRemoteConfig() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .success
        deviceMock.addMockData(Self.responseData(body: .openRemoteConfig(expectedOpenRemoteConfig)))

        _ = try await channel.sendOpenRemoteConfig(mqttBrokerUrl: "mqtts://", mqttUser: "test", mqttPassword: "pwd", assetId: "123")
    }

    @Test func validSendOpenRemoteConfigFailure() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .fail
        deviceMock.addMockData(Self.responseData(body: .openRemoteConfig(expectedOpenRemoteConfig)))

        await #expect(throws: ORConfigChannelError.operationFailure) {
            _ = try await channel.sendOpenRemoteConfig(mqttBrokerUrl: "mqtts://", mqttUser: "test", mqttPassword: "pwd", assetId: "123")
        }
    }

    @Test func sendOpenRemoteConfigWrongResponseType() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedBackendConnectionStatus = Response.BackendConnectionStatus()
        expectedBackendConnectionStatus.status = .connected
        deviceMock.addMockData(Self.responseData(body: .backendConnectionStatus(expectedBackendConnectionStatus)))

        await #expect(throws: ORConfigChannelError.invalidResponse("Invalid response type")) {
            _ = try await channel.sendOpenRemoteConfig(mqttBrokerUrl: "mqtts://", mqttUser: "test", mqttPassword: "pwd", assetId: "123")
        }
    }

    // MARK: GetBackendConnectionStatus

    @Test func validGetBackendConnectionStatus() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedBackendConnectionStatus = Response.BackendConnectionStatus()
        expectedBackendConnectionStatus.status = .connected
        deviceMock.addMockData(Self.responseData(body: .backendConnectionStatus(expectedBackendConnectionStatus)))

        let status = try await channel.getBackendConnectionStatus()
        #expect(status == .connected)
    }

    @Test func getBackendConnectionStatusWrongResponseType() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedOpenRemoteConfig = Response.OpenRemoteConfig()
        expectedOpenRemoteConfig.status = .success
        deviceMock.addMockData(Self.responseData(body: .openRemoteConfig(expectedOpenRemoteConfig)))

        await #expect(throws: ORConfigChannelError.invalidResponse("Invalid response type")) {
            _ = try await channel.getBackendConnectionStatus()
        }
    }

    @Test func getBackendConnectionStatusInvalidStatus() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        var expectedBackendConnectionStatus = Response.BackendConnectionStatus()
        expectedBackendConnectionStatus.status = .UNRECOGNIZED(42)
        deviceMock.addMockData(Self.responseData(body: .backendConnectionStatus(expectedBackendConnectionStatus)))

        await #expect(throws: ORConfigChannelError.invalidResponse("Invalid backend connection status: 42")) {
            _ = try await channel.getBackendConnectionStatus()
        }
    }

    // MARK: ExitProvisioning

    @Test func validExitProvisioning() async throws {
        var channel = ORConfigChannel(device: deviceMock)

        deviceMock.addMockData(Self.responseData(body: .exitProvisioning(Response.ExitProvisioning())))

        try await channel.exitProvisioning()
    }

    // MARK: Helper

    static func responseData(id: String = "0",
                              result: Response.ResponseResult.Result = .success,
                              body: Response.OneOf_Body = .deviceInfo(Response.DeviceInfo())) -> Data {
        var response = Response()
        response.id = id
        var responseResult = Response.ResponseResult()
        responseResult.result = result
        response.result = responseResult
        response.body = body
        return try! response.serializedBytes()
    }
}
