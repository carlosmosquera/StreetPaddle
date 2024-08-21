//
//  Shop.swift
//  StreetPaddle
//
//  Created by Carlos Mosquera on 4/15/24.
//

import SwiftUI
import WebKit


// Define a struct to represent a product
struct Product {
    var id: Int
    var name: String
    var price: Float
    var imageName: String // Name of the image in the Assets acatalog
    var url: URL
}

// Sample array of products
let sampleProducts = [
    Product(id: 1, name: "A night with Aaron", price: 10000.00, imageName: "Aaron", url: URL(string: "https://www.instagram.com/aaronbencid/?hl=en")!),
    Product(id: 2, name: "Black Hoodie", price: 50.00, imageName: "blackHoodie", url: URL(string: "https://streetpaddle1.myshopify.com/products/black-hoodie-1")!),
    Product(id: 3, name: "Black Shirt", price: 35.00, imageName: "BlackShirt", url: URL(string: "https://streetpaddle1.myshopify.com/products/black-t-shirt-2")!),
    Product(id: 4, name: "Sandy Hat", price: 9.99, imageName: "hat", url: URL(string: "https://streetpaddle1.myshopify.com/products/sandy-hat")!),
    // Add more products here...
]

// Product view to display product details
struct ProductView: View {
    var product: Product
    
    var body: some View {
        VStack {
            Image(product.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
            
            Text(product.name)
                .font(.headline)
            Text("$\(product.price, specifier: "%.2f")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.black)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// Main ContentView to display a list of products
struct Shop: View {
    var body: some View {
        NavigationView {
            
            ZStack {
                
                Image(.fence)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 20) {
                                        ForEach(sampleProducts, id: \.id) { product in
                                            NavigationLink(destination: WebView(url: product.url)) {
                                                ProductView(product: product)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Shop")
               
            }
        }
    }
}

struct WebView: View {
    let url: URL

    var body: some View {
        WebViewWrapper(url: url)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebViewWrapper: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> WebViewController {
        let webViewController = WebViewController()
        webViewController.url = url
        return webViewController
    }

    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {
        uiViewController.url = url
    }
}

class WebViewController: UIViewController {
    var webView: WKWebView!
    var url: URL!

    override func loadView() {
        webView = WKWebView()
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let request = URLRequest(url: url)
        webView.load(request)
    }
}


#Preview {
    Shop()

}
