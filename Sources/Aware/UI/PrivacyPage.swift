/**
 Settings → Privacy. Plain-language data use via the shared iUX privacy page.
 */
import SwiftUI
import iUXiOS

struct PrivacyPage: View {
    var body: some View {
        PrivacyInfoPage(content: AwarePrivacyContent.page)
    }
}
