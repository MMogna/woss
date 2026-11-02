// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// One snap target. Stored in config.json as a 6-element array, exactly like the
/// Python version: ["Left Half", 0, 0, 0.5, 1, "left"]  → name, x, y, w, h, hotkey.
public struct Layout: Equatable, Codable {
    public var name: String
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public var hotkey: String

    public init(name: String, x: Double, y: Double, w: Double, h: Double, hotkey: String) {
        self.name = name
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.hotkey = hotkey
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        name = try c.decode(String.self)
        x = try c.decode(Double.self)
        y = try c.decode(Double.self)
        w = try c.decode(Double.self)
        h = try c.decode(Double.self)
        hotkey = try c.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(name)
        try c.encode(x)
        try c.encode(y)
        try c.encode(w)
        try c.encode(h)
        try c.encode(hotkey)
    }

    public var rect: RelRect { RelRect(x: x, y: y, w: w, h: h) }
}

/// A rectangle in screen fractions (0...1), y measured from the bottom.
public struct RelRect: Equatable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}
