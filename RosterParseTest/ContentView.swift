//
//  ContentView.swift
//  RosterParseTest
//
//  Created by Michael Fusaro on 11/3/24.
//
import SwiftUI
import Foundation
import UIKit // Add this to access UIApplication

// Define structs to store roster data
struct RosterData {
    var armyName: String?
    var armySize: Int?
    var armyFaction: String?
    var detachment: String?
    var battleSize: Int?
    var factionLink: String?
    var units: [Unit] = []
}

struct Unit: Identifiable {
    var id = UUID() // Unique identifier for List conformance
    var name: String
    var points: Int
    var category: String
    var faction: String
    var wahaLink: String
    var weapons: [String] = []
}

// Function to load Datasheets.csv and normalize unit names
func loadWahaLinks(from csvPath: String) -> [String: [[String: String]]] {
    var wahaLinks: [String: [[String: String]]] = [:]

    do {
        let data = try String(contentsOfFile: csvPath)
        let rows = data.components(separatedBy: "\n")

        for row in rows {
            let columns = row.components(separatedBy: "|")
            if columns.count >= 14 {
                let unitName = columns[1]
                    .lowercased()
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "'", with: "")
                let factionId = columns[2].trimmingCharacters(in: .whitespaces)
                let link = columns[13].trimmingCharacters(in: .whitespaces)

                let entry = ["faction_id": factionId, "link": link]
                wahaLinks[unitName, default: []].append(entry)
            }
        }
    } catch {
        print("Error loading CSV file: \(error)")
    }

    return wahaLinks
}

// Function to load Factions.csv and store the data
func loadFactions(from csvPath: String) -> [String: [String: String]] {
    var factions: [String: [String: String]] = [:]

    do {
        let data = try String(contentsOfFile: csvPath)
        let rows = data.components(separatedBy: "\n")

        for row in rows {
            let columns = row.components(separatedBy: "|")
            if columns.count >= 3 {
                let factionId = columns[0]
                let name = columns[1]
                let link = columns[2]
                
                factions[factionId] = ["name": name, "link": link]
            }
        }
    } catch {
        print("Error loading Factions CSV file: \(error)")
    }

    return factions
}

// Helper function to find the Wahapedia link for a unit
func findWahaLink(unitName: String, factionId: String?, unitCategory: String?, rosterFactionId: String, wahaLinks: [String: [[String: String]]], factions: [String: [String: String]]) -> String {
    let normalizedUnitName = unitName
        .lowercased()
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "'", with: "")

    if let entries = wahaLinks[normalizedUnitName] {
        if unitCategory != "ALLIED UNITS" {
            for entry in entries {
                if entry["faction_id"] == rosterFactionId {
                    return entry["link"] ?? "#"
                }
            }
        } else {
            for entry in entries {
                if entry["faction_id"] != rosterFactionId {
                    return entry["link"] ?? "#"
                }
            }
        }
    }

    print("No URL found for \(unitName) with faction \(factionId ?? "N/A")")
    return "#" // Return a default value if no link is found
}

// Function to parse the Warhammer roster
func parseWarhammerRoster(_ rosterText: String, wahaLinks: [String: [[String: String]]], factionData: [String: [String: String]], rosterFactionId: String) -> RosterData {
    var rosterData = RosterData()
    var units: [Unit] = []
    var currentUnit: Unit? = nil
    var unitCategory: String? = nil

    let lines = rosterText.components(separatedBy: .newlines)
    let pointsRegex = try! NSRegularExpression(pattern: "\\((\\d+)\\s+[Pp]oints\\)")
    let unitNameRegex = try! NSRegularExpression(pattern: "^(.+?)\\s+\\((\\d+)\\s+[Pp]oints\\)")

    for (index, line) in lines.enumerated() {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        if index == 0 {
            rosterData.armyName = trimmedLine.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces)
            if let match = pointsRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) {
                if let range = Range(match.range(at: 1), in: trimmedLine) {
                    rosterData.armySize = Int(trimmedLine[range])
                }
            }
        } else if index == 2 {
            rosterData.armyFaction = trimmedLine
            rosterData.factionLink = factionData[rosterFactionId]?["link"]
        } else if index == 3 || index == 4 {
            if let match = pointsRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) {
                if let range = Range(match.range(at: 1), in: trimmedLine), trimmedLine.contains("Points") {
                    rosterData.battleSize = Int(trimmedLine[range])
                    rosterData.detachment = index == 3 ? lines[4].trimmingCharacters(in: .whitespaces) : lines[3].trimmingCharacters(in: .whitespaces)
                } else {
                    rosterData.detachment = trimmedLine
                }
            }
        } else if ["CHARACTERS", "BATTLELINE", "DEDICATED TRANSPORTS", "OTHER DATASHEETS", "ALLIED UNITS"].contains(trimmedLine.uppercased()) {
            unitCategory = trimmedLine
        } else if let match = unitNameRegex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)) {
            if let nameRange = Range(match.range(at: 1), in: trimmedLine), let pointsRange = Range(match.range(at: 2), in: trimmedLine) {
                let unitName = String(trimmedLine[nameRange]).trimmingCharacters(in: .whitespaces)
                let unitPoints = Int(trimmedLine[pointsRange]) ?? 0

                let wahaLink = findWahaLink(unitName: unitName, factionId: rosterFactionId, unitCategory: unitCategory, rosterFactionId: rosterFactionId, wahaLinks: wahaLinks, factions: factionData)
                currentUnit = Unit(name: unitName, points: unitPoints, category: unitCategory ?? "-", faction: rosterData.armyFaction ?? "-", wahaLink: wahaLink)
                units.append(currentUnit!)
            }
        } else if trimmedLine.hasPrefix("•"), var currentUnit = currentUnit {
            let weapon = trimmedLine.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces)
            currentUnit.weapons.append(weapon)
            units[units.count - 1] = currentUnit // Update the last element in units array
        }
    }

    rosterData.units = units
    return rosterData
}

struct ContentView: View {
    @State private var rosterText: String = ""
    @State private var rosterData: RosterData? = nil
    @State private var savedFiles: [String] = []
    @State private var showLoadSheet = false

    private let csvPath: String
    private let factionPath: String
    private let wahaLinks: [String: [[String: String]]]
    private let factionData: [String: [String: String]]
    private let rosterFactionId = "DG" // Example roster faction ID

    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.csvPath = documentsDirectory.appendingPathComponent("Datasheets.csv").path
        self.factionPath = documentsDirectory.appendingPathComponent("Factions.csv").path
        
        print("Documents Directory: \(documentsDirectory.path)")
        
        self.wahaLinks = loadWahaLinks(from: self.csvPath)
        self.factionData = loadFactions(from: self.factionPath)
    }

    var body: some View {
        VStack {
            Text("KYE : OhanaTech")
                .font(.largeTitle)
                .padding()

            // Display parsed roster table if available
            if let roster = rosterData {
                VStack(alignment: .leading) {
                    Text("Army Name: \(roster.armyName ?? "Unknown")")
                    Text("Army Size: \(roster.armySize ?? 0) Points")
                    Text("Faction: \(roster.armyFaction ?? "Unknown")")
                    Text("Detachment: \(roster.detachment ?? "Unknown")")
                    Text("Battle Size: \(roster.battleSize ?? 0) Points")
                }
                .padding()

                List(roster.units) { unit in
                    HStack {
                        Text(unit.category)
                        Text(unit.name)
                        Text("\(unit.points) Points")
                        
                        Button("Link") {
                            if let url = URL(string: unit.wahaLink), url.absoluteString != "#" {
                                UIApplication.shared.open(url)
                            } else {
                                print("Invalid or missing URL for unit: \(unit.name)")
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        VStack {
                            ForEach(unit.weapons, id: \.self) { weapon in
                                Text(weapon)
                            }
                        }
                    }
                }
            }

            // Roster text editor and buttons
            TextEditor(text: $rosterText)
                .frame(height: 200) // Specify a height for better layout management
                .border(Color.gray, width: 1)
                .padding()

            HStack {
                Button("Generate") {
                    rosterData = parseWarhammerRoster(rosterText, wahaLinks: wahaLinks, factionData: factionData, rosterFactionId: rosterFactionId)
                }
                
                Button("Save") {
                    saveRoster()
                }
                
                Button("Load") {
                    loadSavedFiles()
                    showLoadSheet.toggle()
                }
            }
            .padding()
        }
        .padding()
        .sheet(isPresented: $showLoadSheet) {
            LoadSheet(savedFiles: savedFiles, onLoad: loadRoster)
        }
    }

    // Save roster to the app's document directory
    private func saveRoster() {
        guard let armyName = rosterData?.armyName else {
            print("Army name not found.")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddyy"
        let dateString = formatter.string(from: Date())
        
        let fileName = "\(armyName.replacingOccurrences(of: " ", with: "_"))_\(dateString).txt"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
        
        do {
            try rosterText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Roster saved to \(fileURL.path)")
        } catch {
            print("Failed to save roster: \(error)")
        }
    }

    // Load saved files in document directory
    private func loadSavedFiles() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            savedFiles = fileURLs.filter { $0.pathExtension == "txt" }.map { $0.lastPathComponent }
            
            // Debug: Print loaded files
            print("Loaded files: \(savedFiles)")
        } catch {
            print("Error loading saved files: \(error)")
        }
    }

    // Load selected roster file into the text editor
    private func loadRoster(fileName: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            rosterText = try String(contentsOf: fileURL, encoding: .utf8)
            print("Roster loaded from \(fileURL.path)")
        } catch {
            print("Failed to load roster: \(error)")
        }
    }
}

// Sheet for loading saved rosters
struct LoadSheet: View {
    var savedFiles: [String]
    var onLoad: (String) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedFile: String? = nil

    var body: some View {
        NavigationView {
            List(savedFiles, id: \.self, selection: $selectedFile) { file in
                Text(file)
            }
            .navigationBarTitle("Load Roster", displayMode: .inline)
            .navigationBarItems(trailing: Button("Load") {
                if let file = selectedFile {
                    onLoad(file)
                    presentationMode.wrappedValue.dismiss()
                }
            })
        }
    }
}
