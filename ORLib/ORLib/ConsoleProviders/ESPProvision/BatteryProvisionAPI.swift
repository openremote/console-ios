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

struct BatteryProvisionAPIREST: BatteryProvisionAPI {

    init(apiURL: URL) {
        self.apiURL = apiURL
    }

    private var apiURL: URL

    func provision(deviceId: String, password: String, token: String) async throws -> String {
        /*
         curl -v http://localhost:8080/api/master/rest/battery -d'{
         "model": 0,
         "deviceId": "123456789ABC",
         "password": "s3cr3t"
         }' -H'Content-type: application/json' -H "Authorization: Bearer $ACCESS_TOKEN"
         */

        let url: URL
        if #available(iOS 16.0, *) {
            url = apiURL.appending(path: "/rest/battery")
        } else {
            url = apiURL.appendingPathComponent("/rest/battery")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONEncoder().encode(ProvisionRequestBody(deviceId: deviceId, password: password))
            print("Request body \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                print("Not an HTTP response ?!?")
                return "ERROR"
            }
            guard (200...299).contains(response.statusCode) else {
                print ("server error, status code \(response.statusCode)")
                return "ERROR" // TODO throw
            }
            if let mimeType = response.mimeType,
               mimeType == "application/json",
               let dataString = String(data: data, encoding: .utf8) {
                print ("got data: \(dataString)")
                let assetId = try JSONDecoder().decode(ProvisionResponseBody.self, from: data).assetId
                return assetId
            }
        } catch {
            print(error.localizedDescription)
            return "ERROR" // TODO throw
        }
        return "ERROR" // TODO how can I get here ?
    }

    struct ProvisionRequestBody: Encodable {
        var deviceId: String
        var password: String
    }

    struct ProvisionResponseBody: Decodable {
        var assetId: String
    }
}
