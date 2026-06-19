public struct SupportedBank: Codable {
    public var bankID: String
    public var name: String

    public init(bankID: String = "", name: String = "") {
        self.bankID = bankID
        self.name = name
    }
}
