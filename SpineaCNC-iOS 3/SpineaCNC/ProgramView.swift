//
//  ProgramView.swift
//  Анализ программы Fanuc с follow-up чатом, кнопками
//  «Улучшить код» и «Объяснить что улучшить».
//

import SwiftUI

struct ProgramView: View {
    @Environment(AppModel.self) private var model

    @State private var code: String = ""
    @State private var result: String = ""
    @State private var streaming: Bool = false
    @State private var lastMode: Mode = .analyze
    @State private var followUpInput: String = ""
    @State private var showFollowUp: Bool = false
    @FocusState private var codeFocused: Bool
    @FocusState private var followUpFocused: Bool

    enum Mode { case analyze, improve, explain }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Заголовок
                    Text(model.t("prog_label"))
                        .font(.caption).bold()
                        .foregroundStyle(Theme.text2)

                    // Поле ввода кода (моноширинное)
                    TextEditor(text: $code)
                        .focused($codeFocused)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Theme.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if code.isEmpty {
                                Text(model.t("prog_ph"))
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(Theme.text3)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    // 3 кнопки действий: Проанализировать / Улучшить / Объяснить
                    actionButtons

                    // Результат
                    if !result.isEmpty || streaming {
                        ResultBlock(
                            title: model.t("result_title"),
                            empty: model.t("result_empty"),
                            text: result
                        )
                        .id("RESULT")
                    }

                    // Follow-up чат (после первого анализа)
                    if showFollowUp {
                        followUpSection
                            .id("FOLLOWUP")
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: result) { _, _ in
                if streaming {
                    withAnimation { proxy.scrollTo("RESULT", anchor: .bottom) }
                }
            }
            .onChange(of: model.programChat.last?.text) { _, _ in
                withAnimation { proxy.scrollTo("FOLLOWUP", anchor: .bottom) }
            }
        }
        .background(Theme.bg)
    }

    // MARK: - Кнопки действий
    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Основная — Проанализировать
            Button {
                Task { await run(mode: .analyze) }
            } label: {
                actionLabel(icon: "doc.text.magnifyingglass",
                            title: model.t("btn_prog"))
            }
            .disabled(!canRun || streaming)

            if !result.isEmpty && !streaming {
                HStack(spacing: 8) {
                    Button {
                        Task { await run(mode: .improve) }
                    } label: {
                        smallActionLabel(icon: "sparkles",
                                         title: model.t("btn_improve"),
                                         color: Theme.blue)
                    }
                    Button {
                        Task { await run(mode: .explain) }
                    } label: {
                        smallActionLabel(icon: "lightbulb",
                                         title: model.t("btn_improve_explain"),
                                         color: Theme.green)
                    }
                }
                .disabled(streaming)
            }
        }
    }

    private func actionLabel(icon: String, title: String) -> some View {
        HStack {
            Spacer()
            if streaming {
                ProgressView().tint(.white)
            } else {
                Image(systemName: icon)
                Text(title).bold()
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .background(canRun ? Theme.red : Theme.text3)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func smallActionLabel(icon: String, title: String, color: Color) -> some View {
        HStack {
            Spacer()
            Image(systemName: icon)
            Text(title).font(.footnote).bold().lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 12)
        .background(color)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canRun: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Follow-up секция
    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 4)
            HStack {
                Text(model.t("prog_chat_ph"))
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)
                Spacer()
                if !model.programChat.isEmpty {
                    Button {
                        model.resetProgramChat()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(Theme.text2)
                    }
                }
            }

            // Сообщения follow-up
            ForEach(model.programChat) { msg in
                ChatBubble(message: msg)
            }

            // Поле ввода вопроса
            HStack(alignment: .bottom, spacing: 8) {
                TextField(model.t("prog_chat_ph"), text: $followUpInput, axis: .vertical)
                    .focused($followUpFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                Button {
                    sendFollowUp()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(canSendFollowUp ? Theme.red : Theme.text3)
                        .clipShape(Circle())
                }
                .disabled(!canSendFollowUp || model.isBusy)
            }
        }
    }

    private var canSendFollowUp: Bool {
        !followUpInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func sendFollowUp() {
        let q = followUpInput
        followUpInput = ""
        followUpFocused = false
        Task {
            await model.sendProgramFollowUp(question: q, programCode: code)
        }
    }

    // MARK: - Запуск анализа
    private func run(mode: Mode) async {
        let codeText = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !codeText.isEmpty else { return }
        guard !model.apiKey.isEmpty else {
            @Bindable var m = model
            m.errorMessage = model.t("err_key")
            return
        }
        codeFocused = false
        result = ""
        streaming = true
        lastMode = mode

        // Выбираем шаблон промпта
        let prompt: String
        let machineText = model.machineProfile.promptText
        let useMachine  = !model.machineProfile.isEmpty

        switch mode {
        case .analyze:
            if useMachine {
                let tmpl = model.t("q_prog_machine")
                prompt = String(format: tmpl, machineText, codeText)
            } else {
                let tmpl = model.t("q_prog")
                prompt = String(format: tmpl, codeText)
            }
        case .improve:
            let tmpl = model.t("q_improve")
            prompt = String(format: tmpl, useMachine ? machineText : "—", codeText)
        case .explain:
            let tmpl = model.t("q_improve_explain")
            prompt = String(format: tmpl, useMachine ? machineText : "—", codeText)
        }

        var full = ""
        do {
            for try await chunk in model.streamSingle(prompt: prompt) {
                full += chunk
                result = full
            }
            model.addHistory(kind: .program, query: codeText, reply: full)
            // Включаем follow-up чат после первого успешного анализа
            if mode == .analyze {
                showFollowUp = true
            }
        } catch {
            result = "❌ \(error.localizedDescription)"
        }
        streaming = false
    }
}

#Preview {
    NavigationStack { ProgramView().environment(AppModel()) }
}
