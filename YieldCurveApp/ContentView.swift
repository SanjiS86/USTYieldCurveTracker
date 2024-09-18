//
//  ContentView.swift
//  YieldCurveApp
//
//  Created by Sanzhi Kobzhan on 17.09.2024.
import SwiftUI
import Charts

func previousWorkingDay(from date: Date) -> Date {
    var previousDate = Calendar.current.date(byAdding: .day, value: -1, to: date)!
    let weekday = Calendar.current.component(.weekday, from: previousDate)
    if weekday == 7 {
        previousDate = Calendar.current.date(byAdding: .day, value: -1, to: previousDate)!
    } else if weekday == 1 {
        previousDate = Calendar.current.date(byAdding: .day, value: -2, to: previousDate)!
    }
    return previousDate
}

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

    func asMaturityYieldPairs() -> [(maturity: String, yield: Double)] {
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

struct YieldDataPoint: Identifiable {
    var id = UUID()
    let dateLabel: String
    let maturity: String
    let yield: Double
}

struct ContentView: View {
    @State private var date1 = Date()
    @State private var date2 = previousWorkingDay(from: Date())

    @State private var yieldData1: YieldData?
    @State private var yieldData2: YieldData?

    @State private var combinedYieldData: [YieldDataPoint] = []

    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack {
                        Text("Date 1")
                            .font(.caption)
                            .foregroundColor(.blue)
                        DatePicker("", selection: $date1, displayedComponents: .date)
                            .labelsHidden()
                            .accentColor(.blue)
                    }
                    .padding()
                    
                    VStack {
                        Text("Date 2")
                            .font(.caption)
                            .foregroundColor(.red)
                        DatePicker("", selection: $date2, displayedComponents: .date)
                            .labelsHidden()
                            .accentColor(.red)
                    }
                    .padding()
                }
       
                Button(action: {
                    Task {
                        await fetchDataForBothDates()
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
    
                if !combinedYieldData.isEmpty {
                                   YieldCurveChart(data: combinedYieldData)
                               }
                
                Spacer()
            }
            .navigationTitle("Treasury Yield Curve")
            .padding()
        }
    }

    func fetchDataForBothDates() async {
        isLoading = true
        errorMessage = ""
        combinedYieldData = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr1 = dateFormatter.string(from: date1)
        let dateStr2 = dateFormatter.string(from: date2)
        let apiKey = ""
        
        let urlStr1 = "https://financialmodelingprep.com/api/v4/treasury?from=\(dateStr1)&to=\(dateStr1)&apikey=\(apiKey)"
        let urlStr2 = "https://financialmodelingprep.com/api/v4/treasury?from=\(dateStr2)&to=\(dateStr2)&apikey=\(apiKey)"
        
        await fetchData(urlStr: urlStr1) { data in
            self.yieldData1 = data.first
        }
        
        await fetchData(urlStr: urlStr2) { data in
            self.yieldData2 = data.first
        }
        
        if let yieldData1 = self.yieldData1 {
            for point in yieldData1.asMaturityYieldPairs() {
                self.combinedYieldData.append(YieldDataPoint(dateLabel: "Date 1", maturity: point.maturity, yield: point.yield))
            }
        }
        
        if let yieldData2 = self.yieldData2 {
            for point in yieldData2.asMaturityYieldPairs() {
                self.combinedYieldData.append(YieldDataPoint(dateLabel: "Date 2", maturity: point.maturity, yield: point.yield))
            }
        }
        
        isLoading = false
    }

    func fetchData(urlStr: String, completion: @escaping ([YieldData]) -> Void) async {
        guard let url = URL(string: urlStr) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL."
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.errorMessage = "API returned status code \(httpResponse.statusCode)"
                    self.isLoading = false
                }
                return
            }
            
            let decodedData = try JSONDecoder().decode([YieldData].self, from: data)
            DispatchQueue.main.async {
                completion(decodedData)
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}


struct YieldCurveChart: View {
    var data: [YieldDataPoint]

    var body: some View {
        let maturityOrder: [String] = ["1M", "2M", "3M", "6M", "1Y", "2Y",
                                       "3Y", "5Y", "7Y", "10Y", "20Y", "30Y"]
        let sortedData = data.sorted {
            maturityOrder.firstIndex(of: $0.maturity)! < maturityOrder.firstIndex(of: $1.maturity)!
        }

        Chart {
            ForEach(["Date 1", "Date 2"], id: \.self) { dateLabel in
                let dataPoints = sortedData.filter { $0.dateLabel == dateLabel }
                let lineColor = dateLabel == "Date 1" ? Color.blue : Color.red

                ForEach(dataPoints.indices.dropFirst(), id: \.self) { index in
                    let previousPoint = dataPoints[index - 1]
                    let currentPoint = dataPoints[index]

                    LineMark(
                        x: .value("Maturity", previousPoint.maturity),
                        y: .value("Yield", previousPoint.yield),
                        series: .value("Date", dateLabel)
                    )
                    .foregroundStyle(lineColor)

                    LineMark(
                        x: .value("Maturity", currentPoint.maturity),
                        y: .value("Yield", currentPoint.yield),
                        series: .value("Date", dateLabel)
                    )
                    .foregroundStyle(lineColor)
                }

                ForEach(dataPoints) { dataPoint in
                    PointMark(
                        x: .value("Maturity", dataPoint.maturity),
                        y: .value("Yield", dataPoint.yield)
                    )
                    .foregroundStyle(lineColor)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: maturityOrder)
        }
        .frame(height: 300)
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
