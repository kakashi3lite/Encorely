import SwiftUI

/// View that displays Core Data error information to users
struct CoreDataErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Error icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.orange)
                        .padding(.top, 30)

                    // Primary message
                    Text("Database Issue Detected")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Description
                    VStack(spacing: 12) {
                        Text("We encountered a problem with the app's database that may affect your mixtapes.")
                            .font(.body)
                            .multilineTextAlignment(.center)

                        Text("Technical details:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(error.localizedDescription)
                            .font(.caption)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: 20)

                    // Actions
                    VStack(spacing: 16) {
                        if let retryAction {
                            Button(action: {
                                retryAction()
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Try Again")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }

                        Button(action: {
                            // Create a support email with error details
                            if let url =
                                URL(
                                    string: "mailto:support@mixtapes.ai?subject=Database%20Error&body=\(error.localizedDescription.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                                )
                            {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                Text("Contact Support")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Dismiss")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            })
        }
        .accentColor(.blue)
    }
}

/// Extension to present Core Data errors from anywhere in the app
extension View {
    func handleCoreDataError(_ error: Binding<Error?>, retryAction: (() -> Void)? = nil) -> some View {
        sheet(item: error.map { $0.map(IdentifiableError.init) }) { identifiableError in
            CoreDataErrorView(error: identifiableError.error, retryAction: retryAction)
                .accentColor(.blue)
        }
    }
}

// Helper to convert Optional<Error> to Binding<NSError?>
extension Binding where Value == Error? {
    func map<T>(_ transform: @escaping (Value) -> T?) -> Binding<T?> {
        Binding<T?>(
            get: { transform(wrappedValue) },
            set: { _ in }
        )
    }
}

// Wrapper to make Error conform to Identifiable
struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error

    init(_ error: Error) {
        self.error = error
    }
}
