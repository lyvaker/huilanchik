//
//  HistoryView.swift
//  История запросов: список с бейджами + детальный просмотр.
//

import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: HistoryEntry?

    var body: some View {
        Group {
            if model.history.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(model.history.reversed()) { entry in
                        Button {
                            selected = entry
                        } label: {
                            row(entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                model.deleteHistoryEntry(entry)
                            } label: {
                                Label(model.t("delete"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            if !model.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        model.clearHistory()
                    } label: {
                        Text(model.t("hist_clear"))
                    }
                }
            }
        }
        .sheet(item: $selected) { entry in
            HistoryDetailView(entry: entry)
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 50))
                .foregroundStyle(Theme.text3)
            Text(model.t("hist_empty"))
                .font(.callout)
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    // MARK: - Row
    private func row(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                badge(for: entry.kind)
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(Theme.text3)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.text3)
            }
            Text(entry.query)
                .font(.callout).bold()
                .lineLimit(2)
                .foregroundStyle(Theme.text)
            Text(entry.reply)
                .font(.footnote)
                .foregroundStyle(Theme.text2)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func badge(for kind: EntryKind) -> some View {
        let (text, color): (String, Color) = {
            switch kind {
            case .alarm:   return (model.t("badge_alarm"), Theme.red)
            case .code:    return (model.t("badge_code"),  Theme.blue)
            case .program: return (model.t("badge_prog"),  Theme.green)
            case .photo:   return (model.t("badge_photo"), .purple)
            case .chat:    return (model.t("badge_chat"),  Theme.text2)
            }
        }()
        return Text(text)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Детальный просмотр записи
struct HistoryDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let entry: HistoryEntry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    Text(entry.date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption)
                        .foregroundStyle(Theme.text3)

                    Text("ЗАПРОС")
                        .font(.caption).bold()
                        .foregroundStyle(Theme.text2)

                    Text(entry.query)
                        .font(.callout)
                        .foregroundStyle(Theme.text)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .textSelection(.enabled)

                    Text(model.t("result_title"))
                        .font(.caption).bold()
                        .foregroundStyle(Theme.text2)
                        .padding(.top, 6)

                    Text(entry.reply)
                        .font(.callout)
                        .foregroundStyle(Theme.text)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .textSelection(.enabled)
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(model.t("ok")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = entry.reply
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}
