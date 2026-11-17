import Foundation

public func evaluate(_ expression: String) -> Double? {
    var parser = ExpressionParser(Array(expression.filter { !$0.isWhitespace }))
    guard let value = parser.parseExpression(), parser.isAtEnd, value.isFinite else { return nil }
    return value
}

public func formatResult(_ value: Double) -> String {
    if value == 0 { return "0" }
    if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
    return String(format: "%.12g", value)
}

private let functions: [String: (Double) -> Double] = [
    "sqrt": { $0.squareRoot() }, "abs": { abs($0) }, "exp": exp, "ln": log, "log": log10,
    "sin": sin, "cos": cos, "tan": tan, "asin": asin, "acos": acos, "atan": atan,
    "floor": { $0.rounded(.down) }, "ceil": { $0.rounded(.up) }, "round": { $0.rounded() },
]

private let constants: [String: Double] = ["pi": .pi, "π": .pi, "e": M_E]

private struct ExpressionParser {
    private let chars: [Character]
    private var index = 0
    private var depth = 0
    private static let maxDepth = 64

    init(_ chars: [Character]) { self.chars = chars }

    var isAtEnd: Bool { index == chars.count }
    private var current: Character? { index < chars.count ? chars[index] : nil }

    private mutating func take(_ options: Set<Character>) -> Character? {
        guard let char = current, options.contains(char) else { return nil }
        index += 1
        return char
    }

    mutating func parseExpression() -> Double? {
        depth += 1
        defer { depth -= 1 }
        guard depth <= Self.maxDepth, var value = parseTerm() else { return nil }
        while let op = take(["+", "-"]) {
            guard let rhs = parseTerm() else { return nil }
            value = op == "+" ? value + rhs : value - rhs
        }
        return value
    }

    private mutating func parseTerm() -> Double? {
        guard var value = parseUnary() else { return nil }
        while true {
            if let op = take(["*", "×", "/", "÷", "%"]) {
                guard let rhs = parseUnary() else { return nil }
                switch op {
                case "*", "×": value *= rhs
                case "%": value = fmod(value, rhs)
                default: value /= rhs
                }
            } else if let char = current, char == "(" || char.isLetter || char == "π" {
                guard let rhs = parsePower() else { return nil }
                value *= rhs
            } else {
                return value
            }
        }
    }

    private mutating func parseUnary() -> Double? {
        if let sign = take(["-", "+"]) {
            guard let value = parseUnary() else { return nil }
            return sign == "-" ? -value : value
        }
        return parsePower()
    }

    private mutating func parsePower() -> Double? {
        guard let base = parsePrimary() else { return nil }
        guard take(["^"]) != nil else { return base }
        depth += 1
        defer { depth -= 1 }
        guard depth <= Self.maxDepth, let exponent = parseUnary() else { return nil }
        return pow(base, exponent)
    }

    private mutating func parsePrimary() -> Double? {
        guard let char = current else { return nil }
        if take(["("]) != nil {
            guard let value = parseExpression(), take([")"]) != nil else { return nil }
            return value
        }
        if char.isNumber || char == "." { return parseNumber() }
        let start = index
        while let letter = current, letter.isLetter || letter == "π" { index += 1 }
        let name = String(chars[start..<index]).lowercased()
        if let function = functions[name] {
            guard take(["("]) != nil, let argument = parseExpression(), take([")"]) != nil else { return nil }
            return function(argument)
        }
        return constants[name]
    }

    private mutating func parseNumber() -> Double? {
        let start = index
        while let char = current, char.isNumber || char == "." { index += 1 }
        if current == "e" || current == "E" {
            let mark = index
            index += 1
            _ = take(["+", "-"])
            if let digit = current, digit.isNumber {
                while let char = current, char.isNumber { index += 1 }
            } else {
                index = mark
            }
        }
        return Double(String(chars[start..<index]))
    }
}
