import  Foundation

public final class WeBirrClient {
    
    private var _apiKey: String
    private var _baseAddress: String
    
    public init(apiKey: String, isTestEnv: Bool){
        
        _apiKey = apiKey
        _baseAddress = isTestEnv ? "https://api.webirr.com" : "https://api.webirr.com:8080"
    }
    
    public func createBillAsync(bill: Bill, callBack:@escaping (ApiResponse<String>) -> Void ) {
        
        let url: URL = URL(string: "\(_baseAddress)/einvoice/api/postbill?api_key=\(_apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONEncoder().encode(bill)
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            
            guard let data = data, error == nil else {
                callBack(ApiResponse(error: error.debugDescription)); return;
            }
            
            do {
                
                
             let resp = try JSONDecoder().decode(ApiResponse<String>.self, from: data)
                
                
                callBack(resp)
                
             //DispatchQueue.main.async {
             //       callBack(resp)
             //}
                
            }
            catch {
                callBack(ApiResponse(error: "http error \(error)"))
            }
            
            }.resume()
    }
    
    public func getPaymentStatus(bill: Bill, callBack:@escaping (ApiResponse<String>) -> Void ) {

        let url: URL = URL(string: "\(_baseAddress)/einvoice/api/postbill?api_key=\(_apiKey)")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            
            guard let data = data, error == nil else {
                callBack(ApiResponse(error: error.debugDescription)); return;
            }
            
            do {
                
             let resp = try JSONDecoder().decode(ApiResponse<String>.self, from: data)
                
                
                
                callBack(resp)
                
             //DispatchQueue.main.async {
             //       callBack(resp)
             //}
                
            }
            catch {
                callBack(ApiResponse(error: "http error \(error)"))
            }
            
            }.resume()
    }

}
