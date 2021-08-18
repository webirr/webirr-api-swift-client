public struct ApiResponse<T : Codable> : Codable {
    
    var error: String? = nil
    var errorCode: String? = nil
    var res : T? = nil
    
    init() {}
    
    init(error: String) {
        self.error = error
    }
    
}
