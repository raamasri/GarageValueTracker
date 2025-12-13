import SwiftUI

struct DealCheckerView: View {
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: String = ""
    @State private var mileage: String = ""
    @State private var askingPrice: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Information")) {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Mileage", text: $mileage)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Asking Price")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Price", text: $askingPrice)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Button(action: {
                        // Check deal logic would go here
                    }) {
                        Text("Check Deal")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                }
                
                Section(header: Text("Coming Soon")) {
                    Text("This feature will help you evaluate if a vehicle is a good deal by comparing the asking price to market values.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Deal Checker")
        }
    }
}

struct DealCheckerView_Previews: PreviewProvider {
    static var previews: some View {
        DealCheckerView()
    }
}
