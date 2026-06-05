//
//  CodesView.swift
//  Объяснение G/M кодов Fanuc.
//

import SwiftUI

struct CodesView: View {
    @Environment(AppModel.self) private var model
    @State private var code: String = ""
    @State private var result: String = ""
    @State private var streaming: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(model.t("code_label"))
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)

                TextField(model.t("code_ph"), text: $code)
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

                Text(model.t("code_quick"))
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)
                    .padding(.top, 6)

                PillGrid(items: model.topPills(
                    smart: model.smartCodes,
                    defaults: QuickLists.codes,
                    count: 8
                )) { item in
                    code = item
                    focused = false
                    Task { await run() }
                }

                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        Spacer()
                        if streaming {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "info.circle")
                            Text(model.t("btn_explain")).bold()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(canRun ? Theme.red : Theme.text3)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canRun || streaming)

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
        !code.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func run() async {
        let q = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard !model.apiKey.isEmpty else {
            @Bindable var m = model
            m.errorMessage = model.t("err_key"); return
        }
        result = ""
        streaming = true

        let template = model.t("q_code")
        let prompt = String(format: template, q)

        var full = ""
        do {
            for try await chunk in model.streamSingle(prompt: prompt) {
                full += chunk
                result = full
            }
            model.addHistory(kind: .code, query: q, reply: full)
            model.bumpCode(q)
        } catch {
            result = "❌ \(error.localizedDescription)"
        }
        streaming = false
    }
}

#Preview {
    NavigationStack {
        CodesView().environment(AppModel())
    }
}
