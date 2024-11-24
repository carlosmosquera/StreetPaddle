import SwiftUI

struct ShopView: View {
    // Sample data
    let items = [
        ShopItem(name: "Drop Shot Pacific Black 4.0", image: "Item1", price: "$210.00", description: "(28 mm hybrid)", url: URL(string: "https://streetpaddle1.myshopify.com/products/drop-shot-pacific-black-4-0-28-mm-hybrid")!),
        ShopItem(name: "Drop Shot Pacific Black 3.0", image: "Item2", price: "$195.00", description: "(28mm Hybrid)", url: URL(string: "https://streetpaddle1.myshopify.com/products/drop-shot-pacific-black-3-0-28mm-hybrid")!),
        ShopItem(name: "Pacific Black 1.0 ", image: "Item3", price: "$249.00", description: "LIMITED EDITION DOERNER", url: URL(string: "https://streetpaddle1.myshopify.com/products/pacific-black-1-0-limited-edition-doerner-1")!)
    ]
    
    // Number of columns in grid
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    ShopItemView(item: item)
                }
            }
            .padding()
        }
        .navigationTitle("Shop")
    }
}

struct ShopItemView: View {
    let item: ShopItem
    
    var body: some View {
        VStack {
            Button(action: {
                openURL(item.url)
            }) {
                Image(item.image)
                    .resizable()
                    .scaledToFit() // Ensures the image fits within the frame and maintains aspect ratio
                    .frame(width: 150, height: 150) // Adjust size as needed
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
            .buttonStyle(PlainButtonStyle()) // Removes default button styling
            
            Text(item.name)
                .font(.headline)
                .padding(.top, 8)
            
            Text(item.price)
                .font(.subheadline)
                .foregroundColor(.green)
                .padding(.top, 4)
            
            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(radius: 4))
    }
    
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
