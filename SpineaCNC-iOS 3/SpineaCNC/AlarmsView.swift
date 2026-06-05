//
//  AlarmsView.swift
//  Расшифровка алармов Fanuc. Ввод кода + быстрые pills + результат со стримингом.
//

import SwiftUI

struct AlarmsView: View {
    @Environment(AppModel.self) private var model
    @State private var alarm: String = ""
    @State private var result: String = ""
    @State private var streaming: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Подпись + поле ввода
                Text(model.t("alarm_label"))
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)

                HStack {
                    TextField(model.t("alarm_ph"), text: $alarm)
                        .focused($focused)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }

                // Быстрые алармы
                Text(model.t("alarm_quick"))
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)
                    .padding(.top, 6)

                PillGrid(items: model.topPills(
                    smart: model.smartAlarms,
                    defaults: QuickLists.alarms,
                    count: 6
                )) { item in
                    alarm = item
                    focused = false
                    Task { await run() }
                }

                // Кнопка действия
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        Spacer()
                        if streaming {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text(model.t("btn_analyze")).bold()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(canRun ? Theme.red : Theme.text3)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canRun || streaming)

                // Результат
                ResultBlock(title: model.t("result_title"),
                            empty: model.t("result_empty"),
                            text: result)
                    .padding(.top, 6)
            }
            .padding(16)
        }
        .background(Theme.bg)
        .scrollDismissesKeyboard(.interactively)
    }

    private var canRun: Bool {
        !alarm.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func run() async {
        let q = alarm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard !model.apiKey.isEmpty else {
            @Bindable var m = model
            m.errorMessage = model.t("err_key"); return
        }

        result = ""
        streaming = true

        let template = model.t("q_alarm")
        let prompt = String(format: template, q)

        var full = ""
        do {
            for try await chunk in model.streamSingle(prompt: prompt) {
                full += chunk
                result = full
            }
            model.addHistory(kind: .alarm, query: q, reply: full)
            model.bumpAlarm(q)
        } catch {
            result = "❌ \(error.localizedDescription)"
        }
        streaming = false
    }
}

// MARK: - PillGrid (адаптивные «таблетки» для быстрых значений)
struct PillGrid: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 90), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.callout).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.bg2)
                        .foregroundStyle(Theme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - Блок результата
struct ResultBlock: View {
    @Environment(AppModel.self) private var model
    let title: String
    let empty: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)
                Spacer()
                if !text.isEmpty {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(Theme.text2)
                    }
                }
            }
            Text(text.isEmpty ? empty : text)
                .font(.callout)
                .foregroundStyle(text.isEmpty ? Theme.text3 : Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.bg2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationStack {
        AlarmsView().environment(AppModel())
    }
}
