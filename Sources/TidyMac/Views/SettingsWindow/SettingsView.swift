import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            FoldersSettingsView()
                .tabItem { Label("Folders", systemImage: "folder") }

            RulesSettingsView()
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }

            ActivitySettingsView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}
