//
//  ContentView.swift
//  YieldCurveApp
//
//  Created by Sanzhi Kobzhan on 17.09.2024.

import SwiftUI
import Charts

struct YieldData: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let month1: Double?
    let month2: Double?
    let month3: Double?
    let month6: Double?
    let year1: Double?
    let year2: Double?
    let year3: Double?
    let year5: Double?
    let year7: Double?
    let year10: Double?
    let year20: Double?
    let year30: Double?

    func asDictionary() -> [(maturity: String, yield: Double)] {
        let dataPoints: [(String, Double?)] = [
            ("1M", month1),
            ("2M", month2),
            ("3M", month3),
            ("6M", month6),
            ("1Y", year1),
            ("2Y", year2),
            ("3Y", year3),
            ("5Y", year5),
            ("7Y", year7),
            ("10Y", year10),
            ("20Y", year20),
            ("30Y", year30)
        ]
        return dataPoints.compactMap { maturity, yield in
            if let yield = yield {
                return (maturity, yield)
            }
            return nil
        }
    }
}

struct ContentView: View {
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var endDate = Date()
    @State private var yieldData: [YieldData] = []
    @State private var curveType = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack {
                        Text("Start Date")
                            .font(.caption)
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding()
                    VStack {
                        Text("End Date")
                            .font(.caption)
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding()
                }

                Button(action: {
                    Task {
                        await fetchData()
                    }
                }) {
                    Text("Fetch Yield Data")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.cornerRadius(10))
                        .foregroundColor(.white)
                }
                .padding()
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                if let latestData = yieldData.first {
                    Chart {
                        ForEach(latestData.asDictionary(), id: \.maturity) { point in
                            LineMark(
                                x: .value("Maturity", point.maturity),
                                y: .value("Yield", point.yield)
                            )
                            .interpolationMethod(.monotone)
                        }
                    }
                    Text(curveType)
                }

                Spacer()
            }
            .navigationTitle("..Yield Curve Analyser..")
            .padding()
        }
    }

    func fetchData() async {
        isLoading = true
        errorMessage = ""

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = dateFormatter.string(from: startDate)
        let toDate = dateFormatter.string(from: endDate)
        let apiKey = ""

        let urlStr = "https://financialmodelingprep.com/api/v4/treasury?from=\(fromDate)&to=\(toDate)&apikey=\(apiKey)"
        guard let url = URL(string: urlStr) else {
            errorMessage = "Invalid URL."
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Error Response: \(jsonString)")
                }
                DispatchQueue.main.async {
                    self.errorMessage = "API returned status code \(httpResponse.statusCode)"
                    self.isLoading = false
                }
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON Response: \(jsonString)")
            }

            let decodedData = try JSONDecoder().decode([YieldData].self, from: data)
            DispatchQueue.main.async {
                self.yieldData = decodedData
                self.analyzeYieldCurve()
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func analyzeYieldCurve() {
        guard let latestData = yieldData.first else { return }

        let shortTermYields = [latestData.month1, latestData.month2, latestData.month3, latestData.month6].compactMap { $0 }
        let longTermYields = [latestData.year10, latestData.year20, latestData.year30].compactMap { $0 }

        guard !shortTermYields.isEmpty, !longTermYields.isEmpty else {
            curveType = "Insufficient data to determine yield curve type."
            return
        }

        let averageShortTermYield = shortTermYields.reduce(0, +) / Double(shortTermYields.count)
        let averageLongTermYield = longTermYields.reduce(0, +) / Double(longTermYields.count)

        if averageShortTermYield > averageLongTermYield {
            curveType = "Inverted Yield Curve. Investors see more risks now than in the longer term"
        } else if averageShortTermYield < averageLongTermYield {
            curveType = "Normal Yield Curve. Investors have higher confidence now than in the longer term"
        } else {
            curveType = "Flat Yield Curve. Investor uncertainty is high"
        }
    }

    func maxYield() -> Double {
        guard let latestData = yieldData.first else { return 5.0 }
        let allYields = latestData.asDictionary().map { $0.yield }
        return (allYields.max() ?? 5.0) + 0.5
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

