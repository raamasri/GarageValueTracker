import Foundation

struct DealInputParser {
    struct ParsedDeal {
        var year: Int?
        var make: String?
        var model: String?
        var trim: String?
        var mileage: Int?
        var price: Double?
        var location: String?
        var url: URL?
    }

    // Model-to-make lookup for when users type model only (e.g. "sc300", "supra", "wrx")
    private static let modelToMake: [String: (make: String, model: String)] = [
        "sc300": ("Lexus", "SC300"), "sc400": ("Lexus", "SC400"),
        "is300": ("Lexus", "IS300"), "is350": ("Lexus", "IS350"), "is500": ("Lexus", "IS500"),
        "gs300": ("Lexus", "GS300"), "gs350": ("Lexus", "GS350"), "gs400": ("Lexus", "GS400"),
        "ls400": ("Lexus", "LS400"), "ls430": ("Lexus", "LS430"),
        "lfa": ("Lexus", "LFA"), "rc350": ("Lexus", "RC350"), "rcf": ("Lexus", "RC F"), "lc500": ("Lexus", "LC500"),
        "supra": ("Toyota", "Supra"), "mr2": ("Toyota", "MR2"), "ae86": ("Toyota", "AE86"),
        "4runner": ("Toyota", "4Runner"), "tacoma": ("Toyota", "Tacoma"),
        "camry": ("Toyota", "Camry"), "corolla": ("Toyota", "Corolla"),
        "rav4": ("Toyota", "RAV4"), "tundra": ("Toyota", "Tundra"),
        "86": ("Toyota", "GR86"), "gr86": ("Toyota", "GR86"),
        "s2000": ("Honda", "S2000"), "nsx": ("Honda", "NSX"),
        "civic": ("Honda", "Civic"), "accord": ("Honda", "Accord"),
        "integra": ("Acura", "Integra"), "rsx": ("Acura", "RSX"),
        "miata": ("Mazda", "MX-5 Miata"), "mx5": ("Mazda", "MX-5 Miata"),
        "rx7": ("Mazda", "RX-7"), "rx8": ("Mazda", "RX-8"),
        "wrx": ("Subaru", "WRX"), "sti": ("Subaru", "WRX STI"), "brz": ("Subaru", "BRZ"),
        "gtr": ("Nissan", "GT-R"), "gt-r": ("Nissan", "GT-R"),
        "350z": ("Nissan", "350Z"), "370z": ("Nissan", "370Z"), "400z": ("Nissan", "Z"),
        "240sx": ("Nissan", "240SX"), "silvia": ("Nissan", "Silvia"),
        "skyline": ("Nissan", "Skyline"),
        "mustang": ("Ford", "Mustang"), "bronco": ("Ford", "Bronco"),
        "f150": ("Ford", "F-150"), "f-150": ("Ford", "F-150"),
        "raptor": ("Ford", "F-150 Raptor"),
        "corvette": ("Chevrolet", "Corvette"), "camaro": ("Chevrolet", "Camaro"),
        "silverado": ("Chevrolet", "Silverado"),
        "challenger": ("Dodge", "Challenger"), "charger": ("Dodge", "Charger"),
        "viper": ("Dodge", "Viper"), "hellcat": ("Dodge", "Challenger Hellcat"),
        "wrangler": ("Jeep", "Wrangler"),
        "911": ("Porsche", "911"), "cayman": ("Porsche", "Cayman"),
        "boxster": ("Porsche", "Boxster"), "cayenne": ("Porsche", "Cayenne"),
        "gt4": ("Porsche", "Cayman GT4"), "gt3": ("Porsche", "911 GT3"),
        "718": ("Porsche", "718"),
        "m3": ("BMW", "M3"), "m4": ("BMW", "M4"), "m5": ("BMW", "M5"),
        "m2": ("BMW", "M2"), "e30": ("BMW", "3 Series"), "e36": ("BMW", "3 Series"),
        "e46": ("BMW", "3 Series"), "e90": ("BMW", "3 Series"), "e92": ("BMW", "3 Series"),
        "f80": ("BMW", "M3"), "g80": ("BMW", "M3"), "g82": ("BMW", "M4"),
        "c63": ("Mercedes-Benz", "C63 AMG"), "e63": ("Mercedes-Benz", "E63 AMG"),
        "g wagon": ("Mercedes-Benz", "G-Class"), "g-wagon": ("Mercedes-Benz", "G-Class"),
        "amg gt": ("Mercedes-Benz", "AMG GT"),
        "rs3": ("Audi", "RS3"), "rs5": ("Audi", "RS5"), "rs6": ("Audi", "RS6"),
        "r8": ("Audi", "R8"), "tt": ("Audi", "TT"), "ttrs": ("Audi", "TT RS"),
        "model 3": ("Tesla", "Model 3"), "model y": ("Tesla", "Model Y"),
        "model s": ("Tesla", "Model S"), "model x": ("Tesla", "Model X"),
        "huracan": ("Lamborghini", "Huracan"), "gallardo": ("Lamborghini", "Gallardo"),
        "488": ("Ferrari", "488"), "f40": ("Ferrari", "F40"), "458": ("Ferrari", "458"),
        "570s": ("McLaren", "570S"), "720s": ("McLaren", "720S"),
        "evo": ("Mitsubishi", "Lancer Evolution"), "lancer": ("Mitsubishi", "Lancer"),
        "golf r": ("Volkswagen", "Golf R"), "gti": ("Volkswagen", "GTI"),
    ]

    static func parse(_ input: String) -> ParsedDeal? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            return ParsedDeal(url: url)
        }

        var result = ParsedDeal()

        // 4-digit year
        let yearPattern4 = #"\b(19[6-9]\d|20[0-3]\d)\b"#
        if let yearMatch = firstMatch(in: text, pattern: yearPattern4) {
            result.year = Int(yearMatch)
        }
        
        // 2-digit year (e.g. "99", "06", "'04") — must not be part of a longer number
        if result.year == nil {
            let yearPattern2 = #"(?:^|['\s,])(\d{2})(?:\s|$|[,\s])"#
            if let shortYear = firstMatch(in: text, pattern: yearPattern2), let val = Int(shortYear) {
                if val >= 60 && val <= 99 {
                    result.year = 1900 + val
                } else if val >= 0 && val <= 30 {
                    result.year = 2000 + val
                }
            }
        }

        // Price: $38,500 or $6,000
        let pricePattern = #"\$\s*([\d,]+(?:\.\d{1,2})?)\s*k?"#
        if let priceMatch = firstMatch(in: text, pattern: pricePattern) {
            let cleaned = priceMatch.replacingOccurrences(of: ",", with: "")
            if let val = Double(cleaned) {
                // Check if the original had "k" suffix
                let dollarKPattern = #"\$\s*[\d,.]+\s*k\b"#
                if firstMatch(in: text, pattern: dollarKPattern) != nil && val < 1000 {
                    result.price = val * 1000
                } else {
                    result.price = val
                }
            }
        }
        
        // Price shorthand: "6k", "38.5k", "95k" (without $)
        if result.price == nil {
            let kPricePattern = #"\b(\d{1,3}(?:\.\d{1,2})?)\s*k\b"#
            let kMatches = allMatches(in: text, pattern: kPricePattern)
            for m in kMatches {
                if let val = Double(m) {
                    let expanded = val * 1000
                    // Skip if this looks like mileage (followed by "mi" or "miles")
                    let mileageCheckPattern = "\(m)\\s*k\\s*(?:mi|miles)"
                    if firstMatch(in: text, pattern: mileageCheckPattern) != nil { continue }
                    if expanded >= 1000 && expanded < 10_000_000 {
                        if result.year != nil && Int(expanded) == result.year! { continue }
                        result.price = expanded
                        break
                    }
                }
            }
        }
        
        // Full numeric price (38500, 95000)
        if result.price == nil {
            let numericPricePattern = #"\b(\d{2,3},?\d{3})\b"#
            let priceMatches = allMatches(in: text, pattern: numericPricePattern)
            for m in priceMatches {
                let cleaned = m.replacingOccurrences(of: ",", with: "")
                if let val = Double(cleaned), val >= 1000, val < 10_000_000 {
                    if result.year != nil && Int(val) == result.year! { continue }
                    result.price = val
                    break
                }
            }
        }

        // Mileage: "150k miles", "62k mi", "150,000 miles", "28k miles"
        let mileageFullPattern = #"(\d{1,3}[,.]?\d{3})\s*(?:mi\b|miles)"#
        if let mileMatch = firstMatch(in: text, pattern: mileageFullPattern) {
            let cleaned = mileMatch.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
            result.mileage = Int(cleaned)
        }
        if result.mileage == nil {
            let shortMilePattern = #"(\d{1,3})\s*k\s*(?:mi\b|miles)"#
            if let match = firstMatch(in: text, pattern: shortMilePattern), let val = Int(match) {
                result.mileage = val * 1000
            }
        }

        // Make detection from known makes list
        let knownMakes = [
            "Toyota", "Honda", "Ford", "Chevrolet", "BMW", "Mercedes-Benz", "Mercedes",
            "Audi", "Porsche", "Lexus", "Subaru", "Mazda", "Nissan", "Hyundai", "Kia",
            "Tesla", "Volkswagen", "VW", "Acura", "Infiniti", "Cadillac", "GMC",
            "RAM", "Dodge", "Jeep", "Volvo", "Land Rover", "Jaguar", "Genesis",
            "Lincoln", "Buick", "Chrysler", "Mitsubishi", "Alfa Romeo", "Maserati",
            "Ferrari", "Lamborghini", "McLaren", "Aston Martin", "Bentley", "Rolls-Royce",
            "Rivian", "Lucid", "Polestar", "Mini", "Fiat", "Scion"
        ]

        for make in knownMakes {
            if text.localizedCaseInsensitiveContains(make) {
                result.make = make
                if let makeRange = text.range(of: make, options: .caseInsensitive) {
                    let afterMake = text[makeRange.upperBound...].trimmingCharacters(in: .whitespaces)
                    let modelWords = afterMake.components(separatedBy: ",").first?
                        .trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: " ") ?? []

                    var modelParts: [String] = []
                    var trimParts: [String] = []
                    var hitNumber = false

                    for w in modelWords {
                        let clean = w.trimmingCharacters(in: .punctuationCharacters)
                        if clean.isEmpty { continue }
                        if Int(clean) != nil { hitNumber = true; continue }
                        if clean.hasPrefix("$") || clean.lowercased().hasSuffix("k") { break }
                        if clean.lowercased() == "mi" || clean.lowercased() == "miles" { break }
                        if hitNumber || modelParts.count >= 2 {
                            trimParts.append(clean)
                        } else {
                            modelParts.append(clean)
                        }
                    }

                    if !modelParts.isEmpty { result.model = modelParts.joined(separator: " ") }
                    if !trimParts.isEmpty { result.trim = trimParts.joined(separator: " ") }
                }
                break
            }
        }

        // Model-to-make lookup if no make was found
        if result.make == nil {
            let lowerText = text.lowercased()
            let words = lowerText.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            
            // Try multi-word matches first ("golf r", "model 3", "amg gt", "g wagon")
            for (key, value) in modelToMake where key.contains(" ") {
                if lowerText.contains(key) {
                    result.make = value.make
                    result.model = value.model
                    break
                }
            }
            
            // Then single-word matches
            if result.make == nil {
                for word in words {
                    if let match = modelToMake[word] {
                        result.make = match.make
                        result.model = match.model
                        break
                    }
                }
            }
            
            // Try concatenated words (e.g. "sc300" as one token)
            if result.make == nil {
                for word in words {
                    for (key, value) in modelToMake {
                        if word == key || word.contains(key) {
                            result.make = value.make
                            result.model = value.model
                            break
                        }
                    }
                    if result.make != nil { break }
                }
            }
        }

        // Location detection
        let stateAbbrevs: Set<String> = ["AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]
        let cities = ["San Diego", "Los Angeles", "San Francisco", "San Jose", "Chicago", "Houston", "Dallas", "Phoenix", "Denver", "Seattle", "Miami", "Atlanta", "Boston", "New York", "Portland", "Austin", "Nashville"]
        for city in cities {
            if text.localizedCaseInsensitiveContains(city) {
                result.location = city
                break
            }
        }
        if result.location == nil {
            let statePattern = #"\b([A-Z]{2})\b"#
            let upperWords = allMatches(in: text, pattern: statePattern)
            for w in upperWords.reversed() {
                if stateAbbrevs.contains(w) {
                    result.location = w
                    break
                }
            }
        }

        guard result.make != nil || result.price != nil || result.year != nil else {
            return nil
        }
        return result
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let groupIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let resultRange = Range(match.range(at: groupIndex), in: text) else { return nil }
        return String(text[resultRange])
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            let groupIndex = match.numberOfRanges > 1 ? 1 : 0
            guard let r = Range(match.range(at: groupIndex), in: text) else { return nil }
            return String(text[r])
        }
    }
}
