import SwiftUI
import CoreLocation

/// A breakdown row: one crime category and its count in the tapped area.
struct CategoryCount: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

/// Summary of reported crime around a tapped map point, for the insights sheet.
struct AreaInsight: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let radiusMeters: CLLocationDistance
    let total: Int
    let breakdown: [CategoryCount]
    let source: String?

    /// A coarse risk band from the raw count — labelling, not science.
    var level: (label: String, color: Color) {
        switch total {
        case 0:      return ("All clear", .green)
        case 1...5:  return ("Low", .green)
        case 6...15: return ("Moderate", .yellow)
        case 16...40: return ("High", .orange)
        default:     return ("Very high", .red)
        }
    }
}

/// Bottom sheet shown when the user taps an area of the heatmap: how much crime
/// was reported nearby, the category mix, the source, and a shortcut to route
/// there.
struct AreaInsightSheet: View {
    let insight: AreaInsight
    /// Called with the tapped coordinate when the user asks to route there.
    var onRoute: (CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss

    private var radiusText: String {
        Measurement(value: insight.radiusMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    var body: some View {
        let level = insight.level
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Headline count + risk band.
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(insight.total)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(level.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.total == 1 ? "report" : "reports")
                                .font(.headline)
                            Text("within \(radiusText)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(level.label)
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(level.color.opacity(0.2)))
                            .foregroundStyle(level.color)
                    }

                    if insight.breakdown.isEmpty {
                        Text("No reported crime in this spot — based on the open data for this area.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Breakdown").font(.headline)
                            ForEach(insight.breakdown.prefix(8)) { row in
                                CategoryBar(row: row, max: insight.breakdown.first?.count ?? 1,
                                            tint: level.color)
                            }
                            if insight.breakdown.count > 8 {
                                Text("+ \(insight.breakdown.count - 8) more categories")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        dismiss()
                        onRoute(insight.coordinate)
                    } label: {
                        Label("Route here safely", systemImage: "figure.walk")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)

                    if let source = insight.source {
                        Text("Source: \(source)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Area insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// A single category row with a proportional bar.
private struct CategoryBar: View {
    let row: CategoryCount
    let max: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.name).font(.subheadline)
                Spacer()
                Text("\(row.count)").font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let frac = max > 0 ? Double(row.count) / Double(max) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(tint.opacity(0.8))
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 6)
        }
    }
}
