public struct ApiResponse<T : Codable> : Codable {
    
    public var error: String? = nil
    public var errorCode: String? = nil
    public var res : T? = nil
    
    public init(error: String? = nil, errorCode: String? = nil, res : T? = nil ){
        self.error = error
        self.errorCode = errorCode
        self.res = res
    }
    
}
