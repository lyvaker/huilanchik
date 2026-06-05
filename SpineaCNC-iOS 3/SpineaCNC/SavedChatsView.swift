//
//  SavedChatsView.swift
//  Список сохранённых чатов (sidebar / sheet на iPhone).
//

import SwiftUI

struct SavedChatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var renameTarget: SavedChat?
    @State private var renameText: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        model.startNewChat()
                        dismiss()
                    } label: {
                        Label(model.t("chat_new"), systemImage: "plus.bubble.fill")
                            .foregroundStyle(Theme.red)
                    }
                }

                Section {
                    if model.savedChats.isEmpty {
                        Text(model.t("hist_empty"))
                            .foregroundStyle(Theme.text3)
                            .font(.callout)
                    } else {
                        ForEach(model.savedChats) { chat in
                            Button {
                                model.openSavedChat(chat)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chat.title)
                                        .font(.callout)
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    Text(chat.updatedAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.text3)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    model.deleteSavedChat(chat)
                                } label: {
                                    Label(model.t("delete"), systemImage: "trash")
                                }
                                Button {
                                    renameTarget = chat
                                    renameText  = chat.title
                                } label: {
                                    Label(model.t("rename"), systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(model.t("chat_new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(model.t("ok")) { dismiss() }
                }
            }
            .alert(model.t("rename"), isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("", text: $renameText)
                Button(model.t("save")) {
                    if let t = renameTarget {
                        model.renameSavedChat(t, to: renameText)
                    }
                    renameTarget = nil
                }
                Button(model.t("cancel"), role: .cancel) {
                    renameTarget = nil
                }
            }
        }
    }
}
