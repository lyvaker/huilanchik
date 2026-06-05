//
//  ChatView.swift
//  Главный экран — чат с AI.
//

import SwiftUI
import PhotosUI

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @State private var inputText: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // ── Лента сообщений ────────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if model.chatMessages.isEmpty {
                            welcomeCard
                                .padding(.top, 24)
                        }
                        ForEach(model.chatMessages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        // Pin-якорь, к которому скроллим при стриминге
                        Color.clear.frame(height: 1).id("BOTTOM")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.chatMessages.last?.text) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .onChange(of: model.chatMessages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .background(Theme.bg)
            }

            // ── Превью прикреплённой картинки ──────────────────────────────
            if let img = model.chatPendingImage {
                attachPreview(img)
            }

            // ── Поле ввода ─────────────────────────────────────────────────
            inputBar
                .background(.ultraThinMaterial)
        }
        .background(Theme.bg)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    @Bindable var m = model
                    m.chatPendingImage = ui
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - Приветствие
    private var welcomeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(Theme.red)
            Text(model.t("chat_welcome"))
                .font(.callout)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.leading)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.bg2)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Превью картинки
    private func attachPreview(_ img: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("📎  Image")
                .font(.footnote)
                .foregroundStyle(Theme.text2)

            Spacer()

            Button {
                @Bindable var m = model
                m.chatPendingImage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.text3)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.bg2)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Theme.border), alignment: .top)
    }

    // MARK: - Поле ввода
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {

            // Кнопка прикрепить
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "paperclip")
                    .font(.title3)
                    .foregroundStyle(Theme.text2)
                    .frame(width: 40, height: 40)
                    .background(Theme.bg3)
                    .clipShape(Circle())
            }

            // Текстовое поле (мульти-строка)
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text(model.t("chat_ph"))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                }
                TextEditor(text: $inputText)
                    .focused($inputFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minHeight: 40, maxHeight: 120)
            }
            .background(Theme.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 1)
            )

            // Кнопка отправить
            Button {
                send()
            } label: {
                Image(systemName: model.isBusy ? "ellipsis" : "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? Theme.red : Theme.text3)
                    .clipShape(Circle())
            }
            .disabled(!canSend || model.isBusy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty ||
        model.chatPendingImage != nil
    }

    private func send() {
        let text = inputText
        inputText = ""
        inputFocused = false
        Task {
            await model.sendChatMessage(text: text)
        }
    }
}

// MARK: - Пузырь сообщения
struct ChatBubble: View {
    @Environment(AppModel.self) private var model
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                avatar
            } else {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if let imgName = message.imagePath, let img = model.loadImage(named: imgName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if !message.text.isEmpty || message.role == .assistant {
                    Text(message.text.isEmpty ? "•••" : message.text)
                        .font(.callout)
                        .foregroundStyle(message.role == .user ? Theme.chatUserText : Theme.chatBotText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.role == .user ? Theme.chatUserBg : Theme.chatBotBg)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = message.text
                            } label: {
                                Label(model.t("copy"), systemImage: "doc.on.doc")
                            }
                        }
                }
            }

            if message.role == .user {
                // у пользователя нет аватарки
            } else {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.avatarAI)
            Image(systemName: "gearshape.fill")
                .foregroundStyle(Theme.avatarAIIcon)
        }
        .frame(width: 32, height: 32)
    }
}

#Preview {
    NavigationStack {
        ChatView()
            .environment(AppModel())
    }
}
