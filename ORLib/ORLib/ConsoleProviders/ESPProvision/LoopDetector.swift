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

class LoopDetector {
    let timeout: TimeInterval
    let maxIterations: Int

    private var startTime: Date?
    private var iterationCount = 0

    init(timeout: TimeInterval = 120, maxIterations: Int = 25) {
        self.timeout = timeout
        self.maxIterations = maxIterations
    }

    func reset() {
        startTime = .now
        iterationCount = 0
    }

    func detectLoop() -> Bool {
        iterationCount += 1
        if iterationCount > maxIterations {
            return true
        }
        guard let startTime else {
            return true
        }
        if Date.now.timeIntervalSince(startTime) > timeout {
            return true
        }
        return false
    }
}


