import SwiftUI

struct ConfirmationDialog: View {
    let title: String
    let message: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let primaryButtonLabel: String
    let secondaryButtonLabel: String
    let destructive: Bool

    init(
        title: String,
        message: String,
        primaryButtonLabel: String = "Confirm",
        secondaryButtonLabel: String = "Cancel",
        destructive: Bool = false,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.primaryButtonLabel = primaryButtonLabel
        self.secondaryButtonLabel = secondaryButtonLabel
        self.destructive = destructive
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button(action: secondaryAction) {
                    Text(secondaryButtonLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: primaryAction) {
                    Text(primaryButtonLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(destructive ? .borderedProminent : .bordered)
                .tint(destructive ? .red : .accentColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
