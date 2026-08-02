import Foundation

/// A small recursive-descent parser/evaluator for the function grapher block — no
/// third-party dependency, just `+ - * / ^`, parens, `sin/cos/tan/sqrt/abs/log/ln/exp`,
/// the constants `pi`/`e`, and the variable `x`. Supports implicit multiplication
/// ("2x", "2(x+1)", "x(x+1)") since that's how students actually write algebra.
enum MathExpression {
    enum ParseError: Error, Equatable {
        case unexpectedCharacter(Character)
        case unexpectedEnd
        case unexpectedToken(String)
    }

    indirect enum Node: Equatable {
        case number(Double)
        case variable
        case negate(Node)
        case add(Node, Node)
        case subtract(Node, Node)
        case multiply(Node, Node)
        case divide(Node, Node)
        case power(Node, Node)
        case call(String, Node)
    }

    /// Parses a function body — accepts either the bare expression ("x^2") or a
    /// "y = ..." / "f(x) = ..." prefix, which is just stripped before parsing.
    static func parse(_ input: String) throws -> Node {
        var body = input.trimmingCharacters(in: .whitespaces)
        if let equals = body.range(of: "=") {
            body = String(body[body.index(after: equals.lowerBound)...])
        }
        var tokenizer = Tokenizer(body)
        let tokens = try tokenizer.tokenize()
        var parser = Parser(tokens)
        let node = try parser.parseExpression()
        try parser.expectEnd()
        return node
    }

    /// Evaluates the parsed expression at `x`; nil for domain errors (sqrt of a
    /// negative, division by zero, log of a non-positive number, etc.) rather than NaN,
    /// so callers can skip the point instead of drawing garbage.
    static func evaluate(_ node: Node, x: Double) -> Double? {
        switch node {
        case .number(let value): return value
        case .variable: return x
        case .negate(let a): return evaluate(a, x: x).map { -$0 }
        case .add(let a, let b): return combine(a, b, x: x, +)
        case .subtract(let a, let b): return combine(a, b, x: x, -)
        case .multiply(let a, let b): return combine(a, b, x: x, *)
        case .divide(let a, let b):
            guard let lhs = evaluate(a, x: x), let rhs = evaluate(b, x: x), rhs != 0 else { return nil }
            return lhs / rhs
        case .power(let a, let b):
            guard let lhs = evaluate(a, x: x), let rhs = evaluate(b, x: x) else { return nil }
            let result = pow(lhs, rhs)
            return result.isFinite ? result : nil
        case .call(let name, let arg):
            guard let value = evaluate(arg, x: x) else { return nil }
            return applyFunction(name, value)
        }
    }

    private static func combine(_ a: Node, _ b: Node, x: Double, _ op: (Double, Double) -> Double) -> Double? {
        guard let lhs = evaluate(a, x: x), let rhs = evaluate(b, x: x) else { return nil }
        let result = op(lhs, rhs)
        return result.isFinite ? result : nil
    }

    private static func applyFunction(_ name: String, _ value: Double) -> Double? {
        switch name {
        case "sin": return sin(value)
        case "cos": return cos(value)
        case "tan": return tan(value)
        case "sqrt": return value >= 0 ? sqrt(value) : nil
        case "abs": return abs(value)
        case "log": return value > 0 ? log10(value) : nil
        case "ln": return value > 0 ? log(value) : nil
        case "exp":
            let result = exp(value)
            return result.isFinite ? result : nil
        default: return nil
        }
    }

    // MARK: - Sampling (for the Canvas-based plot)

    struct Point {
        let x: Double
        let y: Double
    }

    /// Evenly samples the function across `[xMin, xMax]`, skipping domain-invalid
    /// points. Returned as separate "runs" (breaks at each invalid point) so the
    /// caller can draw a path per run instead of connecting across a discontinuity.
    static func sample(_ node: Node, xMin: Double, xMax: Double, count: Int = 240) -> [[Point]] {
        guard count > 1, xMax > xMin else { return [] }
        var runs: [[Point]] = []
        var current: [Point] = []
        for i in 0..<count {
            let x = xMin + (xMax - xMin) * Double(i) / Double(count - 1)
            if let y = evaluate(node, x: x), y.isFinite {
                current.append(Point(x: x, y: y))
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    /// A y-range that comfortably fits the sampled points, clamped so a single
    /// near-asymptote spike doesn't blow out the whole plot's scale.
    static func yBounds(for runs: [[Point]], clampMagnitude: Double = 1000) -> ClosedRange<Double>? {
        let ys = runs.flatMap { $0.map(\.y) }.filter { abs($0) <= clampMagnitude }
        guard let lo = ys.min(), let hi = ys.max() else { return nil }
        if lo == hi {
            return (lo - 1)...(hi + 1)
        }
        let padding = (hi - lo) * 0.1
        return (lo - padding)...(hi + padding)
    }
}

private struct Tokenizer {
    enum Token: Equatable {
        case number(Double)
        case identifier(String)
        case op(Character)
        case lparen
        case rparen
    }

    private let chars: [Character]
    private var index = 0

    init(_ text: String) {
        self.chars = Array(text)
    }

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while index < chars.count {
            let c = chars[index]
            if c.isWhitespace {
                index += 1
            } else if c.isNumber || c == "." {
                tokens.append(.number(try readNumber()))
            } else if c.isLetter {
                tokens.append(.identifier(readIdentifier()))
            } else if "+-*/^".contains(c) {
                tokens.append(.op(c))
                index += 1
            } else if c == "(" {
                tokens.append(.lparen)
                index += 1
            } else if c == ")" {
                tokens.append(.rparen)
                index += 1
            } else {
                throw MathExpression.ParseError.unexpectedCharacter(c)
            }
        }
        return tokens
    }

    private mutating func readNumber() throws -> Double {
        var text = ""
        while index < chars.count, chars[index].isNumber || chars[index] == "." {
            text.append(chars[index])
            index += 1
        }
        guard let value = Double(text) else { throw MathExpression.ParseError.unexpectedToken(text) }
        return value
    }

    private mutating func readIdentifier() -> String {
        var text = ""
        while index < chars.count, chars[index].isLetter {
            text.append(chars[index])
            index += 1
        }
        return text
    }
}

private struct Parser {
    private let tokens: [Tokenizer.Token]
    private var index = 0

    private static let functionNames: Set<String> = ["sin", "cos", "tan", "sqrt", "abs", "log", "ln", "exp"]
    private static let constants: [String: Double] = ["pi": .pi, "e": M_E]

    init(_ tokens: [Tokenizer.Token]) {
        self.tokens = tokens
    }

    private var current: Tokenizer.Token? {
        index < tokens.count ? tokens[index] : nil
    }

    mutating func expectEnd() throws {
        guard current == nil else { throw MathExpression.ParseError.unexpectedToken("\(current!)") }
    }

    // expression := term (('+' | '-') term)*
    mutating func parseExpression() throws -> MathExpression.Node {
        var node = try parseTerm()
        while case .op(let c)? = current, c == "+" || c == "-" {
            index += 1
            let rhs = try parseTerm()
            node = c == "+" ? .add(node, rhs) : .subtract(node, rhs)
        }
        return node
    }

    // term := power (('*' | '/' | <implicit>) power)*
    private mutating func parseTerm() throws -> MathExpression.Node {
        var node = try parsePower()
        while true {
            if case .op(let c)? = current, c == "*" || c == "/" {
                index += 1
                let rhs = try parsePower()
                node = c == "*" ? .multiply(node, rhs) : .divide(node, rhs)
            } else if startsFactor(current) {
                // Implicit multiplication: "2x", "2(x+1)", "x(x+1)".
                let rhs = try parsePower()
                node = .multiply(node, rhs)
            } else {
                break
            }
        }
        return node
    }

    private func startsFactor(_ token: Tokenizer.Token?) -> Bool {
        switch token {
        case .number, .identifier, .lparen: return true
        default: return false
        }
    }

    // power := unary ('^' power)?  (right-associative)
    private mutating func parsePower() throws -> MathExpression.Node {
        let base = try parseUnary()
        if case .op("^")? = current {
            index += 1
            let exponent = try parsePower()
            return .power(base, exponent)
        }
        return base
    }

    // unary := '-' unary | primary
    private mutating func parseUnary() throws -> MathExpression.Node {
        if case .op("-")? = current {
            index += 1
            return .negate(try parseUnary())
        }
        if case .op("+")? = current {
            index += 1
            return try parseUnary()
        }
        return try parsePrimary()
    }

    // primary := number | '(' expression ')' | identifier ['(' expression ')']
    private mutating func parsePrimary() throws -> MathExpression.Node {
        guard let token = current else { throw MathExpression.ParseError.unexpectedEnd }
        switch token {
        case .number(let value):
            index += 1
            return .number(value)
        case .lparen:
            index += 1
            let inner = try parseExpression()
            try expect(.rparen)
            return inner
        case .identifier(let name):
            index += 1
            if case .lparen? = current {
                index += 1
                let arg = try parseExpression()
                try expect(.rparen)
                if Self.functionNames.contains(name) {
                    return .call(name, arg)
                }
                // Unknown-name-as-function ("x(x+1)") is implicit multiplication.
                return .multiply(try nodeForIdentifier(name), arg)
            }
            return try nodeForIdentifier(name)
        case .rparen, .op:
            throw MathExpression.ParseError.unexpectedToken("\(token)")
        }
    }

    private func nodeForIdentifier(_ name: String) throws -> MathExpression.Node {
        if name == "x" { return .variable }
        if let constant = Self.constants[name] { return .number(constant) }
        throw MathExpression.ParseError.unexpectedToken(name)
    }

    private mutating func expect(_ token: Tokenizer.Token) throws {
        guard current == token else {
            throw MathExpression.ParseError.unexpectedToken(current.map { "\($0)" } ?? "end of input")
        }
        index += 1
    }
}
