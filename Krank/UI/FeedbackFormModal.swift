import SwiftUI

struct FeedbackFormModal: View {
    let isDarkMode: Bool
    let onClose: () -> Void
    let onSubmit: (FeedbackType, String) -> Void

    @State private var selectedType: FeedbackType = .suggestion
    @State private var message = ""
    @State private var validationMessage: String?

    private let typeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var primaryTextColor: Color {
        isDarkMode ? Color(red: 0.93, green: 0.95, blue: 0.98) : BrandColors.navy
    }

    private var secondaryTextColor: Color {
        isDarkMode ? Color(red: 0.63, green: 0.69, blue: 0.79) : BrandColors.navyMuted
    }

    private var modalBackground: Color {
        isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.99)
    }

    private var rowBackground: Color {
        isDarkMode ? Color(red: 0.17, green: 0.19, blue: 0.24) : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    private var selectedTypeBackground: Color {
        isDarkMode ? Color(red: 0.18, green: 0.31, blue: 0.39) : Color(red: 0.86, green: 0.94, blue: 0.99)
    }

    private var selectedTypeStroke: Color {
        Color(red: 0.13, green: 0.58, blue: 0.88)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Give Feedback")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 32, height: 32)
                        .background(rowBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close feedback form"))
            }

            Text("Tell us what would make KRANK better.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Type")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryTextColor.opacity(0.86))

                LazyVGrid(columns: typeColumns, spacing: 10) {
                    ForEach(FeedbackType.allCases) { type in
                        feedbackTypeButton(type)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Message")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryTextColor.opacity(0.86))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(rowBackground)

                    if message.isEmpty {
                        Text("What should we know?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(secondaryTextColor.opacity(0.58))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                    }

                    TextEditor(text: $message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(primaryTextColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                .frame(height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(validationMessage == nil ? Color.clear : Color(red: 0.84, green: 0.20, blue: 0.24), lineWidth: 1.5)
                )

                if let validationMessage {
                    Text(validationMessage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.84, green: 0.20, blue: 0.24))
                }
            }

            HStack(spacing: 10) {
                Button(action: onClose) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(rowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: submit) {
                    Text("Send Feedback")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BrandColors.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(20)
        .background(modalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
        .onChange(of: message) { _, _ in
            validationMessage = nil
        }
    }

    private func feedbackTypeButton(_ type: FeedbackType) -> some View {
        let isSelected = selectedType == type

        return Button {
            selectedType = type
        } label: {
            Text(type.rawValue)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isSelected ? selectedTypeStroke : primaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? selectedTypeBackground : rowBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? selectedTypeStroke : Color.clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(type.rawValue))
    }

    private func submit() {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            validationMessage = "Please enter a message first."
            return
        }

        onSubmit(selectedType, trimmedMessage)
    }
}
