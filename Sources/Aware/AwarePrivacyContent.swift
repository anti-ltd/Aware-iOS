/**
 Aware privacy copy for `PrivacyInfoPage`.
 */
import SwiftUI
import iUXiOS

enum AwarePrivacyContent {
    static let page = PrivacyContent(
        heroTitle: "Your data, plainly",
        heroSubtitle: "No account to create. Aware stores your profile and contacts on your phone and only talks to the network when a map feature needs live data.",
        pledges: [
            .init(label: "No account", symbol: "person.crop.circle.badge.xmark", tint: .mint),
            .init(label: "No ads", symbol: "megaphone.fill", tint: .orange),
            .init(label: "No analytics", symbol: "chart.bar.xaxis", tint: .purple),
        ],
        localColumn: .init(
            title: "On your iPhone",
            symbol: "iphone.gen3",
            tint: .green,
            items: [
                "Emergency medical profile",
                "Trusted contacts and alert preferences",
                "Active SOS, live-share, and check-in sessions",
                "Settings and onboarding state",
            ]
        ),
        networkedColumn: .init(
            title: "Networked",
            symbol: "network",
            tint: .blue,
            items: [
                "Map area when the crime heatmap is on",
                "MapKit tiles, search, and directions",
                "SMS links when you send an SOS or share live",
            ]
        ),
        topics: [
            .init(
                id: 0,
                title: "What stays local",
                symbol: "internaldrive.fill",
                tint: .green,
                lead: "Your safety profile never uploads to an Aware account because there isn't one.",
                bullets: [
                    "Emergency medical info, allergies, and notes live on-device only.",
                    "Trusted contacts are stored locally after you import or add them.",
                    "Check-in timers and safety sessions persist between launches on your phone.",
                    "Widgets and Live Activities read the same on-device session state as the app.",
                ]
            ),
            .init(
                id: 1,
                title: "Location",
                symbol: "location.fill",
                tint: .blue,
                lead: "GPS powers the safety map and sharing — not a location history we keep.",
                bullets: [
                    "The map, nearby services, and route planning use location while Aware is open.",
                    "SOS and live sharing can keep updating in the background when you turn that on.",
                    "Aware does not upload your coordinates to our servers.",
                    "Crime heatmap queries send only the map box you're viewing to anti.ltd.",
                ]
            ),
            .init(
                id: 2,
                title: "anti.ltd relay",
                symbol: "server.rack",
                tint: .indigo,
                lead: "A small Cloudflare Worker proxies open crime feeds so your phone doesn't hammer each city API.",
                bullets: [
                    "Your phone sends the visible map bounds. No name, email, or device trail.",
                    "The active crime source is credited on the map.",
                    "We don't sell this data or use it for ads.",
                ]
            ),
            .init(
                id: 3,
                title: "Apple Maps",
                symbol: "map.fill",
                tint: .teal,
                lead: "Tiles, search, and walking directions run through MapKit on your phone.",
                bullets: [
                    "Nearby police, hospitals, pharmacies, and transport come from MapKit Local Search.",
                    "Safer routes use MapKit Directions with optional crime weighting on-device.",
                    "Those requests follow Apple's Maps privacy policy, not a separate Aware account.",
                ]
            ),
            .init(
                id: 4,
                title: "Permissions",
                symbol: "hand.raised.fill",
                tint: .orange,
                lead: "Everything is optional. Deny any permission and Aware still opens.",
                bullets: [
                    "Location: map, routes, SOS, live sharing, and check-in timer.",
                    "Contacts: import trusted people from your address book.",
                    "Notifications: check-in timer alerts and safety reminders.",
                ]
            ),
            .init(
                id: 5,
                title: "Your controls",
                symbol: "slider.horizontal.3",
                tint: .pink,
                lead: "Turn features off or delete data any time.",
                bullets: [
                    "Toggle the crime heatmap and safer routes in Settings.",
                    "Turn off background location for SOS when you don't need it.",
                    "Remove trusted contacts from the roster inside the app.",
                    "Delete the app and your local data is gone. Reinstall starts fresh.",
                ]
            ),
        ],
        footerBody: "Aware is built by anti.ltd. For third-party crime feeds and coverage regions, see Sources and Coverage in Settings.",
        footerLink: URL(string: "https://anti.ltd"),
        footerLinkLabel: "anti.ltd",
        lastUpdated: "June 2026"
    )
}
