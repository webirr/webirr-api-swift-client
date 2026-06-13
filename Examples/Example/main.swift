import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"
let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

let savedPaymentCode = "PAYMENT_CODE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL"
let savedBillReference = "BILL_REFERENCE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL"

createAndUpdateBillAsync()
getPaymentStatusAsync(paymentCode: savedPaymentCode)
getBillAndListBillsAsync(billReference: savedBillReference, paymentCode: savedPaymentCode)
deleteBillAsync(paymentCode: savedPaymentCode)
BulkPaymentPollingConsumer(api: api).fetchAndProcessPayments()
getStatAsync()

/**
 * Creating a new Bill / Updating an existing Bill on WeBirr Servers
 */
func createAndUpdateBillAsync() {
    var bill = Bill(
        customerCode: "cc01", // it can be email address or phone number if you dont have customer code
        customerName: "Elias Haileselassie",
        billReference: "swift/2021/143", // your unique reference number
        time: "2021-07-22 22:14", // your bill time, always in this format
        description: "hotel booking",
        amount: "270.90",
        customerPhone: "0911000000",
        extras: [:])

    print("Creating Bill...")

    wait { done in
        api.createBillAsync(bill: bill) { resp in
            if resp.error == nil {
                // success
                let paymentCode = resp.res ?? "" // returns paymentcode such as 429 723 975
                print("Payment Code = \(paymentCode)") // we may want to save payment code in local db.
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT_DUP_REF
            }
            done()
        }
    }

    // update existing bill if it is not paid
    bill.amount = "278.00"
    bill.customerName = "Elias swift"
    //bill.billReference = "WE SHOULD NOT CHANGE THIS";

    print("Updating Bill...")

    wait { done in
        api.updateBillAsync(bill: bill) { resp in
            if resp.error == nil {
                // success
                print("bill is updated successfully") //it.res will be 'OK'  no need to check here!
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
            }
            done()
        }
    }
}

/**
 * Getting a Bill and Listing Bills
 */
func getBillAndListBillsAsync(billReference: String, paymentCode: String) {
    print("Getting Bill By Reference...")

    wait { done in
        api.getBillByReferenceAsync(billReference: billReference) { resp in
            if resp.error == nil {
                // success
                print("Payment Code = \(resp.res?.wbcCode ?? "")")
                print("Payment Status = \(resp.res?.paymentStatus ?? 0)")
                print("Last Timestamp = \(resp.res?.updateTimeStamp ?? "")")
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")")
            }
            done()
        }
    }

    print("Getting Bill By Payment Code...")

    wait { done in
        api.getBillByPaymentCodeAsync(paymentCode: paymentCode) { resp in
            if resp.error == nil {
                // success
                print("Bill Reference = \(resp.res?.billReference ?? "")")
                print("Payment Status = \(resp.res?.paymentStatus ?? 0)")
                print("Last Timestamp = \(resp.res?.updateTimeStamp ?? "")")
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")")
            }
            done()
        }
    }

    print("Listing Bills...")
    let paymentStatus = -1 // -1 all, 0 pending, 1 unconfirmed payment, 2 paid.
    let lastTimeStamp = "20251231" // Date-only cursor; use "20251231235959" when you need time precision.
    let limit = 10

    wait { done in
        api.getBillsAsync(paymentStatus: paymentStatus, lastTimeStamp: lastTimeStamp, limit: limit) { resp in
            if resp.error == nil {
                // success
                print("Bills returned: \(resp.res?.count ?? 0)")
                for bill in resp.res ?? [] {
                    print("Bill Reference = \(bill.billReference)")
                    print("Payment Code = \(bill.wbcCode)")
                    print("Payment Status = \(bill.paymentStatus)")
                    print("Last Timestamp = \(bill.updateTimeStamp)")
                }
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")")
            }
            done()
        }
    }
}

/**
 * Getting Payment status of an existing Bill from WeBirr Servers
 */
func getPaymentStatusAsync(paymentCode: String) {
    print("Getting Payment Status...")

    wait { done in
        api.getPaymentStatusAsync(paymentCode: paymentCode) { resp in
            if resp.error == nil {
                // success
                if resp.res?.isPaid ?? false {
                    print("bill is paid")
                    print("bill payment detail")
                    print("Bank: \(resp.res?.data?.bankID  ?? "")")
                    print("Bank Reference Number: \(resp.res?.data?.paymentReference  ?? "")")
                    print("Amount Paid: \(resp.res?.data?.amount  ?? "")")
                    print("Payment Date: \(resp.res?.data?.paymentDate  ?? "")")
                } else {
                    print("bill is pending payment")
                }
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
            }
            done()
        }
    }
}

/**
 * Deleting an existing Bill from WeBirr Servers (if it is not paid)
 */
func deleteBillAsync(paymentCode: String) {
    print("Deleting Bill...")

    wait { done in
        api.deleteBillAsync(paymentCode: paymentCode) { resp in
            if resp.error == nil {
                // success
                print("bill is deleted successfully") //res.res will be 'OK'  no need to check here!
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
            }
            done()
        }
    }
}

/**
 * Getting list of Payments and process them with Bulk Polling Consumer
 */
class BulkPaymentPollingConsumer {
    private let api: WeBirrClient
    private var lastTimeStamp = "20251231" // use a saved cursor; time precision can be like "20251231235959"

    init(api: WeBirrClient) {
        self.api = api
    }

    func fetchAndProcessPayments() {
        let limit = 100

        print("Getting Payments...")

        wait { done in
            api.getPaymentsAsync(lastTimeStamp: lastTimeStamp, limit: limit) { resp in
                if resp.error == nil {
                    // success
                    for payment in resp.res ?? [] {
                        processPayment(payment)
                        if !payment.updateTimeStamp.isEmpty {
                            self.lastTimeStamp = payment.updateTimeStamp
                            print("Last Timestamp: \(self.lastTimeStamp)") // save updateTimeStamp to your database for the next getPaymentsAsync() call
                        }
                    }
                } else {
                    // fail
                    print("error: \(resp.error!)")
                    print("errorCode: \(resp.errorCode ?? "")")
                }
                done()
            }
        }
    }
}

/**
 * Gettting basic Statistics about bills created and payments received for a date range
 */
func getStatAsync() {
    let dateFrom = "2025-01-01"
    let dateTo = "2030-01-31"

    print("Getting Stat...")

    wait { done in
        api.getStatAsync(dateFrom: dateFrom, dateTo: dateTo) { resp in
            if resp.error == nil {
                // success
                print("Bills Created: \(resp.res?.nBills ?? 0)")
                print("Bills Paid: \(resp.res?.nBillsPaid ?? 0)")
                print("Bills Unpaid: \(resp.res?.nBillsUnpaid ?? 0)")
                print("Amount Bills: \(resp.res?.amountBills ?? 0)")
                print("Amount Paid: \(resp.res?.amountPaid ?? 0)")
                print("Amount Unpaid: \(resp.res?.amountUnpaid ?? 0)")
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")")
            }
            done()
        }
    }
}

/**
 * Webhooks - Payment processing using Webhook Callbacks
 */
func processWebhookPayment(rawBody: Data, authKey: String?) -> (statusCode: Int, body: String) {
    let expectedAuthKey = ProcessInfo.processInfo.environment["WEBIRR_WEBHOOK_AUTH_KEY"] ?? "YOUR_WEBHOOK_AUTH_KEY"

    guard authKey == expectedAuthKey else {
        return (401, "{\"error\":\"unauthorized\"}")
    }

    guard !rawBody.isEmpty else {
        return (400, "{\"error\":\"empty request body\"}")
    }

    do {
        let payment = try JSONDecoder().decode(PaymentResponse.self, from: rawBody)
        processPayment(payment)
        return (200, "{\"error\":null}")
    } catch {
        return (400, "{\"error\":\"invalid json\"}")
    }
}

func processPayment(_ payment: PaymentResponse) {
    if payment.isPaid {
        print("bill is paid")
    } else if payment.isReversed {
        print("bill payment is reversed")
    }

    print("Bank: \(payment.bankID)")
    print("Bank Reference Number: \(payment.paymentReference)")
    print("Amount Paid: \(payment.amount)")
    print("Payment Date: \(payment.paymentDate)")
    print("Canceled Time: \(payment.canceledTime)")
    print("Update Timestamp: \(payment.updateTimeStamp)")
}

func wait(_ operation: (@escaping () -> Void) -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    operation {
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 15)
}
