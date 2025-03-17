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

struct DeviceInfo {
    let deviceId: String
    let modelName: String
}

enum BackendConnectionStatus {
    case disconnected
    case connecting
    case connected
    case failed
}

struct ORConfigChannel {
    let device: ORESPDevice

    var messageId = 0

    mutating func getDeviceInfo() async throws -> DeviceInfo {
        var deviceInfoRequest = Request()
        deviceInfoRequest.body = .deviceInfo(Request.DeviceInfo())

        let response = try await sendRequest(deviceInfoRequest)

        if case let .deviceInfo(deviceInfo) = response.body {
            return DeviceInfo(deviceId: deviceInfo.deviceID, modelName: deviceInfo.modelName)
        } else {
            throw ORConfigChannelError.invalidResponse("Invalid response type")
        }
    }

    mutating func sendOpenRemoteConfig(mqttBrokerUrl: String,
                                       mqttUser: String,
                                       mqttPassword: String,
                                       realm: String = "master",
                                       assetId: String) async throws {
        var openRemoteConfigRequest = Request()
        var config = Request.OpenRemoteConfig()
        config.mqttBrokerURL = mqttBrokerUrl
        config.user = mqttUser
        config.mqttPassword = mqttPassword
        config.assetID = assetId
        config.realm = realm
        openRemoteConfigRequest.body = .openRemoteConfig(config)

        let response = try await sendRequest(openRemoteConfigRequest)

        if case let .openRemoteConfig(status) = response.body {
            if status.status != .success {
                throw ORConfigChannelError.operationFailure
            }
        } else {
            throw ORConfigChannelError.invalidResponse("Invalid response type")
        }
    }

    mutating func getBackendConnectionStatus() async throws -> BackendConnectionStatus {
        var statusRequest = Request()
        statusRequest.body = .backendConnectionStatus(Request.BackendConnectionStatus())

        let response = try await sendRequest(statusRequest)

        if case let .backendConnectionStatus(status) = response.body {
            switch status.status {
            case .disconnected:
                return .disconnected
            case .connecting:
                return .connecting
            case .connected:
                return .connected
            case .failed:
                return .failed
            case .UNRECOGNIZED(let int):
                throw ORConfigChannelError.invalidResponse("Invalid backend connection status: \(int)")
            }
        } else {
            throw ORConfigChannelError.invalidResponse("Invalid response type")
        }
    }

    mutating func exitProvisioning() async throws {
        var request = Request()
        request.body = .exitProvisioning(Request.ExitProvisioning())

        _ = try await sendRequest(request)
    }

    private mutating func sendRequest(_ request: Request) async throws -> Response {
        var request = request
        request.id = String(messageId)
        messageId += 1

        do {
            let data: Data? = try request.serializedBytes()
            guard let requestData = data else {
                throw ORConfigChannelError.invalidRequest("Error serializing request")
            }
            return try await withCheckedThrowingContinuation { continuation in
                device.sendData(path: "or-cfg", data: requestData) { responseData, error in
                    if let error {
                        // TODO:
                        print("Error: \(error.localizedDescription)")
                        continuation.resume(throwing: ORConfigChannelError.genericError)
                    } else if let responseData {
                        do {
                            let response = try Response(serializedBytes: responseData)
                            if response.id != request.id {
                                continuation.resume(throwing: ORConfigChannelError.messageOutOfOrder)
                                return
                            }

                            if !response.hasResult {
                                continuation.resume(throwing: ORConfigChannelError.invalidResponse("Response has no result"))
                                return
                            }

                            if response.result.result != .success {
                                continuation.resume(throwing: ORConfigChannelError.invalidResponse("Response result is \(response.result.result)"))
                                return
                            }

                            continuation.resume(returning: response)
                        } catch {
                            continuation.resume(throwing: ORConfigChannelError.invalidResponse(error.localizedDescription))
                        }
                    } else {
                        continuation.resume(throwing: ORConfigChannelError.invalidResponse("No response received"))
                    }
                }
            }
        } catch let error as ORConfigChannelError {
            throw error
        } catch {
            throw ORConfigChannelError.invalidRequest(error.localizedDescription)
        }
    }
}

enum ORConfigChannelError: Error {
    /// Request can't be created or not accepted by other party, provides reason as String
    case invalidRequest(String)
    /// Received a response that does not match the request id
    /// For now, we only allow simple request / response and expects messages to be in order
    case messageOutOfOrder
    /// Received response is invalid, provides reason as String
    case invalidResponse(String)
    /// Other party did execute request but it resulted in a failure
    case operationFailure
    /// General error occured during request/response process
    case genericError
}

extension ORConfigChannelError: Equatable {
    static func ==(lhs: ORConfigChannelError, rhs: ORConfigChannelError) -> Bool {
        switch (lhs, rhs) {
           case (.invalidRequest(let leftReason), .invalidRequest(let rightReason)),
                (.invalidResponse(let leftReason), .invalidResponse(let rightReason)):
               return leftReason == rightReason
           case (.messageOutOfOrder, .messageOutOfOrder),
                (.operationFailure, .operationFailure),
                (.genericError, .genericError):
               return true
           default:
               return false
           }
       }
}

#if DEBUG
// TODO: see https://stackoverflow.com/a/60267724 for improvement
extension ORConfigChannel {
    public mutating func publicSendRequest(_ request: Request) async throws -> Response {
        return try await self.sendRequest(request)
    }
}
#endif
