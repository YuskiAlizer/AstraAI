import Foundation

/// A JSON value type that can be encoded/decoded and used as input/output
/// for skills. Supports null, bool, number, string, array, and object.
indirect enum JSONValue: Codable, Equatable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Double.self) {
            self = .number(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([JSONValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: JSONValue].self) {
            self = .object(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let v):
            try container.encode(v)
        case .number(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        case .array(let v):
            try container.encode(v)
        case .object(let v):
            try container.encode(v)
        }
    }

    // MARK: - Convenience Accessors

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let v) = self { return v }
        if case .string(let s) = self { return Double(s) }
        return nil
    }

    var intValue: Int? {
        doubleValue.map(Int.init)
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        if case .string(let s) = self { return s.lowercased() == "true" }
        if case .number(let n) = self { return n != 0 }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self { return dict[key] }
        return nil
    }

    subscript(index: Int) -> JSONValue? {
        if case .array(let arr) = self, arr.indices.contains(index) { return arr[index] }
        return nil
    }

    /// Encodes this value to a JSON string.
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "null" }
        return String(data: data, encoding: .utf8) ?? "null"
    }

    /// Parses a JSONValue from a JSON string.
    static func from(jsonString: String) -> JSONValue? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }
}
