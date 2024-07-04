import SwiftUI
import HealthKit
import Firebase

struct FirebaseService {
    let baseURL = ApiKeyInfo.baseURL
    let apiKey = ApiKeyInfo.apiKey
    
    func postData(nodePath: String, data: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)\(nodePath).json?auth=\(apiKey)") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [])
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                print("Error sending data: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            if (200...299).contains(httpResponse.statusCode) {
                print("Successfully sent data to Firebase Realtime Database")
                completion(true)
            } else {
                print("Failed to send data with HTTP status: \(httpResponse.statusCode)")
                completion(false)
            }
        }.resume()
    }
}

struct ContentView: View {
    private var healthStore = HKHealthStore()
    let heartRateQuantity = HKUnit(from: "count/min")
    let respRateQuantity = HKUnit(from: "count/min")
    let otwosatQuantity = HKUnit(from: "%")
//    let queryGroup = DispatchGroup()

    
    @State private var value: Double = 0
    @State private var oSatVal: Double = 0
    @State private var respVal: Double = 0
    @State var stop: Bool = true
    @State var count: Int = 0
    var timer = Timer()
    var secondsElapsed = 0.0
    @State var startTime: Date = Date()
    
    var body: some View {
        VStack{
            HStack{
                Text("❤️")
                    .font(.system(size: 50))
                Spacer()
                
            }
            
            HStack{
                Text("\(Int(value))")
                    .fontWeight(.regular)
                    .font(.system(size: 70))
                
                Text("BPM")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.red)
                    .padding(.bottom, 28.0)
                
                Spacer()
                
            }
            
        }
        .padding()
        .onAppear(perform: start)
    }
    
    
    
    func start() {
        autorizeHealthKit()
//        queryGroup.enter()
                    startHeartRateQuery(quantityTypeIdentifier: .heartRate)
//                    startHeartRateQuery(quantityTypeIdentifier: .oxygenSaturation)
//                    startHeartRateQuery(quantityTypeIdentifier: .respiratoryRate)
//        queryGroup.leave()

        callFunc()
    }
    
    func autorizeHealthKit() {
        let healthKitTypes: Set = [
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!, HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.respiratoryRate)!]
        
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { _, _ in }
    }
    
    func callFunc() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let heartRateData = ["heartRate": value, "timestamp": Int(Date().timeIntervalSince1970)] as [String : Any]
                FirebaseService().postData(nodePath: "heartRates", data: heartRateData, completion: { success in
                    if success {
                        print("Data posted successfully.")
                    } else {
                        print("Failed to post data.")
                    }
                })
                callFunc()
            }
        }
    
    private func startHeartRateQuery(quantityTypeIdentifier: HKQuantityTypeIdentifier) {
        
        // 1
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        // 2
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            query, samples, deletedObjects, queryAnchor, error in
            
            // 3
            guard let samples = samples as? [HKQuantitySample] else {
                return
            }
            
            self.process(samples, type: quantityTypeIdentifier)
            
        }
        
        // 4
        let query = HKAnchoredObjectQuery(type: HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!, predicate: devicePredicate, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: updateHandler)
        
        query.updateHandler = updateHandler
        
        // 5
        healthStore.execute(query)
    }
    
    private func process(_ samples: [HKQuantitySample], type: HKQuantityTypeIdentifier) {
        var lastHeartRate = 0.0
        var lastSatRate = 0.0
        var lastRespRate = 0.0
        
        for sample in samples {
            if type == .heartRate {
                lastHeartRate = sample.quantity.doubleValue(for: heartRateQuantity)
            } else if type == .oxygenSaturation{
                lastSatRate = sample.quantity.doubleValue(for: otwosatQuantity)
            } else if type == .respiratoryRate{
                lastRespRate = sample.quantity.doubleValue(for: respRateQuantity)
            }
            
            self.value = lastHeartRate
            self.respVal = lastRespRate
            self.oSatVal = lastSatRate
            let current = Date()
            let diffComponents = Calendar.current.dateComponents([.second, .nanosecond], from: self.startTime, to: current)
            let seconds = Double(diffComponents.second ?? 0) + Double(diffComponents.nanosecond ?? 0) / 1_000_000_000
            print("heartrate is: \(Int(value)) after \(seconds) seconds")
            print("resp rate is: \(Int(respVal)) after \(seconds) seconds")
            print("sat rate is: \(oSatVal) after \(seconds) seconds")
            startTime = Date()
            
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
