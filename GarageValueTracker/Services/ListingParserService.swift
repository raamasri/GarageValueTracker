import Foundation

class ListingParserService {
    static let shared = ListingParserService()
    
    private init() {}
    
    struct ParsedListing {
        var make: String?
        var model: String?
        var year: Int?
        var trim: String?
        var mileage: Int?
        var price: Double?
        var vin: String?
        var imageURL: String?
        var seller: String?
        var source: String?
        var title: String?
    }
    
    // MARK: - Parse URL
    
    func parse(url: URL, completion: @escaping (ParsedListing?) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let source = self.detectSource(url: url)
            var result = ParsedListing(source: source)
            
            self.parseJSONLD(html: html, into: &result)
            self.parseOpenGraph(html: html, into: &result)
            self.parseSiteSpecific(html: html, source: source, into: &result)
            self.parseTitle(html: html, into: &result)
            self.extractVIN(html: html, into: &result)
            
            if result.year == nil || result.make == nil {
                self.inferFromTitle(result: &result)
            }
            
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
    
    // MARK: - Source Detection
    
    private func detectSource(url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("autotrader") { return "Autotrader" }
        if host.contains("cars.com") { return "Cars.com" }
        if host.contains("carvana") { return "Carvana" }
        if host.contains("ebay") { return "eBay Motors" }
        if host.contains("facebook") { return "Facebook Marketplace" }
        if host.contains("craigslist") { return "Craigslist" }
        if host.contains("bringatrailer") || host.contains("bat") { return "Bring a Trailer" }
        if host.contains("carsandbids") { return "Cars & Bids" }
        return "Unknown"
    }
    
    // MARK: - JSON-LD Parsing
    
    private func parseJSONLD(html: String, into result: inout ParsedListing) {
        let pattern = #"<script\s+type="application/ld\+json"[^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
        let range = NSRange(html.startIndex..., in: html)
        
        let matches = regex.matches(in: html, range: range)
        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange])
            
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            let type = json["@type"] as? String ?? ""
            guard type.lowercased().contains("vehicle") || type.lowercased().contains("product") || type.lowercased().contains("car") else { continue }
            
            if let name = json["name"] as? String { result.title = name }
            if let brand = json["brand"] as? [String: Any], let brandName = brand["name"] as? String {
                result.make = brandName
            }
            if let model = json["model"] as? String { result.model = model }
            if let yearStr = json["vehicleModelDate"] as? String, let year = Int(yearStr) { result.year = year }
            if let mileage = json["mileageFromOdometer"] as? [String: Any], let value = mileage["value"] as? String {
                result.mileage = Int(value.replacingOccurrences(of: ",", with: ""))
            }
            if let offers = json["offers"] as? [String: Any], let price = offers["price"] as? String {
                result.price = Double(price.replacingOccurrences(of: ",", with: ""))
            } else if let price = json["offers"] as? [String: Any], let priceNum = price["price"] as? Double {
                result.price = priceNum
            }
            if let vin = json["vehicleIdentificationNumber"] as? String { result.vin = vin }
        }
    }
    
    // MARK: - Open Graph Tags
    
    private func parseOpenGraph(html: String, into result: inout ParsedListing) {
        if result.title == nil {
            result.title = extractMeta(html: html, property: "og:title")
        }
        if result.imageURL == nil {
            result.imageURL = extractMeta(html: html, property: "og:image")
        }
        if let priceStr = extractMeta(html: html, property: "product:price:amount") ?? extractMeta(html: html, property: "og:price:amount") {
            if result.price == nil {
                result.price = Double(priceStr.replacingOccurrences(of: ",", with: ""))
            }
        }
    }
    
    // MARK: - Site-Specific Parsing
    
    private func parseSiteSpecific(html: String, source: String, into result: inout ParsedListing) {
        if result.price == nil {
            let pricePatterns = [
                #"\$[\s]*([0-9]{1,3}(?:,?[0-9]{3})+)"#,
                #"\"price\"\s*:\s*\"?([0-9,.]+)"#,
                #"listing-price[^>]*>[\s]*\$([0-9,]+)"#
            ]
            for pattern in pricePatterns {
                if let match = firstMatch(in: html, pattern: pattern) {
                    let cleaned = match.replacingOccurrences(of: ",", with: "")
                    if let price = Double(cleaned), price > 1000 && price < 10_000_000 {
                        result.price = price
                        break
                    }
                }
            }
        }
        
        if result.mileage == nil {
            let mileagePatterns = [
                #"([0-9]{1,3}(?:,?[0-9]{3})+)\s*(?:mi|miles|mi\.)"#,
                #"mileage[^0-9]*([0-9,]+)"#,
                #"odometer[^0-9]*([0-9,]+)"#
            ]
            for pattern in mileagePatterns {
                if let match = firstMatch(in: html, pattern: pattern) {
                    let cleaned = match.replacingOccurrences(of: ",", with: "")
                    if let mileage = Int(cleaned), mileage > 0 && mileage < 1_000_000 {
                        result.mileage = mileage
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Title Parsing
    
    private func parseTitle(html: String, into result: inout ParsedListing) {
        if result.title == nil {
            if let titleContent = extractTag(html: html, tag: "title") {
                result.title = titleContent.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    // MARK: - VIN Extraction
    
    private func extractVIN(html: String, into result: inout ParsedListing) {
        guard result.vin == nil else { return }
        let vinPattern = #"\b([A-HJ-NPR-Z0-9]{17})\b"#
        if let match = firstMatch(in: html, pattern: vinPattern) {
            result.vin = match
        }
    }
    
    // MARK: - Infer from Title
    
    private func inferFromTitle(result: inout ParsedListing) {
        guard let title = result.title else { return }
        
        let yearPattern = #"\b(19[89]\d|20[0-3]\d)\b"#
        if result.year == nil, let yearStr = firstMatch(in: title, pattern: yearPattern) {
            result.year = Int(yearStr)
        }
    }
    
    // MARK: - Helpers
    
    private func extractMeta(html: String, property: String) -> String? {
        let pattern = #"<meta\s+(?:property|name)="\#(NSRegularExpression.escapedPattern(for: property))"\s+content="([^"]*)"#
        return firstMatch(in: html, pattern: pattern)
    }
    
    private func extractTag(html: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]*)</\(tag)>"
        return firstMatch(in: html, pattern: pattern)
    }
    
    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let groupIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let resultRange = Range(match.range(at: groupIndex), in: text) else { return nil }
        return String(text[resultRange])
    }
}
