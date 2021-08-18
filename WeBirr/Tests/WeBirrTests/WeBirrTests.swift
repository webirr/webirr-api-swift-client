    import XCTest
    @testable import WeBirr

    final class WeBirrTests: XCTestCase {
        
        func testCreateBill_should_get_error_from_WebService_on_invalid_api_key_TestEnv() {
            
            let bill = sampleBill
            let api = WeBirrClient(apiKey: "x", isTestEnv: true)

            var errorCode: String?
            
            api.createBillAsync(bill: bill) { resp in
                errorCode = resp.errorCode
                
                print("/(resp.error)")
            }
            
            Thread.sleep(forTimeInterval: 2)
            XCTAssertNotNil(errorCode)
        }
        
        func testCreateBill_should_get_error_from_WebService_on_invalid_api_key_ProdEnv() {
            
            let bill = sampleBill
            let api = WeBirrClient(apiKey: "x", isTestEnv: false)

            var errorCode: String?
            
            api.createBillAsync(bill: bill) { resp in
                errorCode = resp.errorCode
            }
            
            Thread.sleep(forTimeInterval: 2)
            XCTAssertNotNil(errorCode)
        }
        var sampleBill = Bill(
        customerCode: "cc01",
        customerName: "Elias Haileselassie",
        billReference: "swift/2021/141",
        time: "2021-07-22 22:14",
        description: "hotel booking",
        amount: "270.90",
        merchantID: "x"
      )
        
    }
