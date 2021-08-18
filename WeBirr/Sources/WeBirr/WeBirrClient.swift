import  Foundation

/**
 * A WeBirrClient instance object can be used to
 * Create, Update or Delete a Bill at WeBirr Servers and also to
 * Get the Payment Status of a bill.
 * It is a wrapper for the REST Web Service API.
 */
public final class WeBirrClient {
    
    private var _apiKey: String
    private var _baseAddress: String
    
    public init(apiKey: String, isTestEnv: Bool){
        
        _apiKey = apiKey
        _baseAddress = isTestEnv ? "https://api.webirr.com" : "https://api.webirr.com:8080"
    }
    
    /**
     * Create a new bill at WeBirr Servers.
     * @param {Bill} bill represents an invoice or bill for a customer
     * @returns {Unit} but uses callBack that will be called when the async task is done.
     * Check if(ApiResponse.error == null) to see if there are errors.
     * ApiResponse.res will have the value of the returned PaymentCode on success.
     */
    public func createBillAsync(bill: Bill, callBack:@escaping (ApiResponse<String>) -> Void ) {
        
        request(.POST, path: "/einvoice/api/postbill?api_key=\(_apiKey)", body: bill, callBack: callBack)

    }
    
    /**
      * Update an existing bill at WeBirr Servers, if the bill is not paid yet.
      * The billReference has to be the same as the original bill created.
      * @param {Bill} bill represents an invoice or bill for a customer
      * @returns {Unit} but uses callBack that will be called when the async task is done.
      * Check if(ApiResponse.error == null) to see if there are errors.
      * ApiResponse.res will have the value of "OK" on success.
      */
    public func updateBillAsync(bill: Bill, callBack:@escaping (ApiResponse<String>) -> Void ) {
        
        request(.PUT, path: "/einvoice/api/postbill?api_key=\(_apiKey)", body: bill, callBack: callBack)

    }
    
    /**
     * Delete an existing bill at WeBirr Servers, if the bill is not paid yet.
     * @param {string} paymentCode is the number that WeBirr Payment Gateway returns on createBillAsync.
     * @returns {Unit} but uses callBack that will be called when the async task is done.
     * Check if(ApiResponse.error == null) to see if there are errors.
     * ApiResponse.res will have the value of "OK" on success.
     */
    public func deleteBillAsync(paymentCode: String, callBack:@escaping (ApiResponse<String>) -> Void ) {

        request(.PUT, path: "/einvoice/api/deletebill?api_key=\(_apiKey)&wbc_code=\(paymentCode)", body: "", callBack: callBack)

    }
   
    /**
     * Get Payment Status of a bill from WeBirr Servers
     * @param {string} paymentCode is the number that WeBirr Payment Gateway returns on createBill.
     * @returns {Unit} but uses callBack that will be called when the async task is done.
     * Check if(returnedResult.error == null) to see if there are errors.
     * ApiResponse.res will have [Payment] object on success (will be null otherwise!)
     * ApiResponse.res?.isPaid ?? false -> will return true if the bill is paid (payment completed)
     * ApiResponse.res?.data ?? null -> will have [PaymentDetail] object
     */
    public func getPaymentStatusAsync(paymentCode: String, callBack:@escaping (ApiResponse<Payment>) -> Void ) {

        request(.GET, path: "/einvoice/api/getpaymentstatus?api_key=\(_apiKey)&wbc_code=\(paymentCode)", body: "", callBack: callBack)
       
    }
    
 // helper method 
    private func request<T : Encodable, V: Decodable>(_ verb: Verb, path: String, body: T, callBack:@escaping (ApiResponse<V>) -> Void ) {
        
        let url: URL = URL(string: "\(_baseAddress)\(path.replacingOccurrences(of: " ", with: ""))")!
        var request = URLRequest(url: url)
        request.httpMethod = verb.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if verb == .POST || verb == .PUT {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try! JSONEncoder().encode(body)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let data = data, error == nil else {
                callBack(ApiResponse(error: error?.localizedDescription)); return;
            }
            
            guard let response = response as? HTTPURLResponse else {
                callBack(ApiResponse(error: "unknown error")); return;
            }
                
            if response.statusCode < 200 || response.statusCode > 299 {
                callBack(ApiResponse(error: "http error \(response.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))")); return;
            }
                
            do {
                let resp = try JSONDecoder().decode(ApiResponse<V>.self, from: data)
                callBack(resp)
            }
            catch let err {
                callBack(ApiResponse(error: "local error \(err)"))
            }
            
            }.resume()
        
    }

}

private enum Verb : String
{
    case GET, POST, PUT
}
