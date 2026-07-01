import Foundation
import WeBirr

@main
struct Example {
    static func main() async throws {
        let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
        let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"
        let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

        let savedPaymentCode = "PAYMENT_CODE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL"
        let savedBillReference = "BILL_REFERENCE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL"

        try await createAndUpdateBill(api: api)
        try await getPaymentStatus(api: api, paymentCode: savedPaymentCode)
        try await getBillAndListBills(api: api, billReference: savedBillReference, paymentCode: savedPaymentCode)
        try await deleteBill(api: api, paymentCode: savedPaymentCode)
        try await BulkPaymentPollingConsumer(api: api).fetchAndProcessPayments()
        try await getStat(api: api)
        try await getSupportedBanks(api: api)
    }

    /**
     * Creating a new Bill / Updating an existing Bill on WeBirr Servers
     */
    static func createAndUpdateBill(api: WeBirrClient) async throws {
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

        let created = try await api.createBill(bill: bill)
        if created.error == nil {
            // success
            let paymentCode = created.res ?? "" // returns paymentcode such as 429 723 975
            print("Payment Code = \(paymentCode)") // we may want to save payment code in local db.
        } else {
            // fail
            print("error: \(created.error!)")
            print("errorCode: \(created.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT_DUP_REF
        }

        // update existing bill if it is not paid
        bill.amount = "278.00"
        bill.customerName = "Elias swift"
        //bill.billReference = "WE SHOULD NOT CHANGE THIS";

        print("Updating Bill...")

        let updated = try await api.updateBill(bill: bill)
        if updated.error == nil {
            // success
            print("bill is updated successfully") //it.res will be 'OK'  no need to check here!
        } else {
            // fail
            print("error: \(updated.error!)")
            print("errorCode: \(updated.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
        }
    }

    /**
     * Getting a Bill and Listing Bills
     */
    static func getBillAndListBills(api: WeBirrClient, billReference: String, paymentCode: String) async throws {
        print("Getting Bill By Reference...")

        let byReference = try await api.getBillByReference(billReference: billReference)
        if byReference.error == nil {
            // success
            print("Payment Code = \(byReference.res?.wbcCode ?? "")")
            print("Payment Status = \(byReference.res?.paymentStatus ?? 0)")
            print("Last Timestamp = \(byReference.res?.updateTimeStamp ?? "")")
        } else {
            // fail
            print("error: \(byReference.error!)")
            print("errorCode: \(byReference.errorCode ?? "")")
        }

        print("Getting Bill By Payment Code...")

        let byPaymentCode = try await api.getBillByPaymentCode(paymentCode: paymentCode)
        if byPaymentCode.error == nil {
            // success
            print("Bill Reference = \(byPaymentCode.res?.billReference ?? "")")
            print("Payment Status = \(byPaymentCode.res?.paymentStatus ?? 0)")
            print("Last Timestamp = \(byPaymentCode.res?.updateTimeStamp ?? "")")
        } else {
            // fail
            print("error: \(byPaymentCode.error!)")
            print("errorCode: \(byPaymentCode.errorCode ?? "")")
        }

        print("Listing Bills...")
        let paymentStatus = -1 // -1 all, 0 pending, 1 unconfirmed payment, 2 paid.
        let lastTimeStamp = "20251231" // Date-only cursor; use "20251231235959" when you need time precision.
        let limit = 10

        let bills = try await api.getBills(paymentStatus: paymentStatus, lastTimeStamp: lastTimeStamp, limit: limit)
        if bills.error == nil {
            // success
            print("Bills returned: \(bills.res?.count ?? 0)")
            for bill in bills.res ?? [] {
                print("Bill Reference = \(bill.billReference)")
                print("Payment Code = \(bill.wbcCode)")
                print("Payment Status = \(bill.paymentStatus)")
                print("Last Timestamp = \(bill.updateTimeStamp)")
            }
        } else {
            // fail
            print("error: \(bills.error!)")
            print("errorCode: \(bills.errorCode ?? "")")
        }
    }

    /**
     * Getting Payment status of an existing Bill from WeBirr Servers
     */
    static func getPaymentStatus(api: WeBirrClient, paymentCode: String) async throws {
        print("Getting Payment Status...")

        let status = try await api.getPaymentStatus(paymentCode: paymentCode)
        if status.error == nil {
            // success
            if status.res?.isPaid ?? false {
                print("bill is paid")
                print("bill payment detail")
                print("Bank: \(status.res?.data?.bankID  ?? "")")
                print("Bank Reference Number: \(status.res?.data?.paymentReference  ?? "")")
                print("Amount Paid: \(status.res?.data?.amount  ?? "")")
                print("Payment Date: \(status.res?.data?.paymentDate  ?? "")")
            } else {
                print("bill is pending payment")
            }
        } else {
            // fail
            print("error: \(status.error!)")
            print("errorCode: \(status.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
        }
    }

    /**
     * Deleting an existing Bill from WeBirr Servers (if it is not paid)
     */
    static func deleteBill(api: WeBirrClient, paymentCode: String) async throws {
        print("Deleting Bill...")

        let deleted = try await api.deleteBill(paymentCode: paymentCode)
        if deleted.error == nil {
            // success
            print("bill is deleted successfully") //res.res will be 'OK'  no need to check here!
        } else {
            // fail
            print("error: \(deleted.error!)")
            print("errorCode: \(deleted.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
        }
    }

    /**
     * Gettting basic Statistics about bills created and payments received for a date range
     */
    static func getStat(api: WeBirrClient) async throws {
        let dateFrom = "2025-01-01"
        let dateTo = "2030-01-31"

        print("Getting Stat...")

        let stat = try await api.getStat(dateFrom: dateFrom, dateTo: dateTo)
        if stat.error == nil {
            // success
            print("Bills Created: \(stat.res?.nBills ?? 0)")
            print("Bills Paid: \(stat.res?.nBillsPaid ?? 0)")
            print("Bills Unpaid: \(stat.res?.nBillsUnpaid ?? 0)")
            print("Amount Bills: \(stat.res?.amountBills ?? 0)")
            print("Amount Paid: \(stat.res?.amountPaid ?? 0)")
            print("Amount Unpaid: \(stat.res?.amountUnpaid ?? 0)")
        } else {
            // fail
            print("error: \(stat.error!)")
            print("errorCode: \(stat.errorCode ?? "")")
        }
    }

    /**
     * Getting banks enabled for this merchant checkout.
     */
    static func getSupportedBanks(api: WeBirrClient) async throws {
        print("Getting Supported Banks...")

        let banks = try await api.getSupportedBanks()
        if banks.error == nil {
            for bank in banks.res ?? [] {
                print("\(bank.bankID) - \(bank.name)")
            }
            print("Use only these merchant-specific banks when showing checkout payment instructions.")
        } else {
            print("error: \(banks.error!)")
            print("errorCode: \(banks.errorCode ?? "")")
        }
    }

    /**
     * Webhooks - Payment processing using Webhook Callbacks
     */
    static func processWebhookPayment(rawBody: Data, authKey: String?) -> (statusCode: Int, body: String) {
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

    static func processPayment(_ payment: PaymentResponse) {
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
}

final class BulkPaymentPollingConsumer {
    private let api: WeBirrClient
    private var lastTimeStamp = "20251231" // use a saved cursor; time precision can be like "20251231235959"

    init(api: WeBirrClient) {
        self.api = api
    }

    func fetchAndProcessPayments() async throws {
        let limit = 100

        print("Getting Payments...")

        let payments = try await api.getPayments(lastTimeStamp: lastTimeStamp, limit: limit)
        if payments.error == nil {
            // success
            for payment in payments.res ?? [] {
                Example.processPayment(payment)
                if !payment.updateTimeStamp.isEmpty {
                    lastTimeStamp = payment.updateTimeStamp
                    print("Last Timestamp: \(lastTimeStamp)") // save updateTimeStamp to your database for the next getPayments() call
                }
            }
        } else {
            // fail
            print("error: \(payments.error!)")
            print("errorCode: \(payments.errorCode ?? "")")
        }
    }
}
