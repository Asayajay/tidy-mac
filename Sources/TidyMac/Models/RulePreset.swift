import Foundation
import TidyMacCore

/// A starting point for a new rule, not a locked-in template. Picking one just
/// pre-fills the name, destination, and conditions in the same editor every other rule
/// uses, so it's still fully editable afterward -- this exists because a blank "New
/// Rule" with an empty condition gave no sense of what else people might want to sort
/// beyond the built-in defaults.
struct RulePreset: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let makeRule: () -> FileRule

    static let all: [RulePreset] = [
        RulePreset(title: "Invoices & receipts", subtitle: "PDFs with \"invoice\" or \"receipt\" in the name") {
            FileRule(
                name: "Invoices & Receipts",
                conditions: [
                    MatchCondition(kind: .filenameContains, value: "invoice"),
                    MatchCondition(kind: .filenameContains, value: "receipt")
                ],
                conditionLogic: .any,
                destinationSubpath: "Documents/Invoices"
            )
        },
        RulePreset(title: "RAW photos", subtitle: "Camera raw formats: .raw, .cr2, .nef, .arw, .dng") {
            FileRule(
                name: "RAW Photos",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "raw"),
                    MatchCondition(kind: .fileExtension, value: "cr2"),
                    MatchCondition(kind: .fileExtension, value: "nef"),
                    MatchCondition(kind: .fileExtension, value: "arw"),
                    MatchCondition(kind: .fileExtension, value: "dng")
                ],
                conditionLogic: .any,
                destinationSubpath: "Pictures/RAW"
            )
        },
        RulePreset(title: "Screen recordings", subtitle: "Video files named like a macOS screen recording") {
            FileRule(
                name: "Screen Recordings",
                conditions: [MatchCondition(kind: .filenamePrefix, value: "Screen Recording")],
                destinationSubpath: "Screen Recordings"
            )
        },
        RulePreset(title: "eBooks", subtitle: ".epub, .mobi, .azw3") {
            FileRule(
                name: "eBooks",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "epub"),
                    MatchCondition(kind: .fileExtension, value: "mobi"),
                    MatchCondition(kind: .fileExtension, value: "azw3")
                ],
                conditionLogic: .any,
                destinationSubpath: "Books"
            )
        },
        RulePreset(title: "Fonts", subtitle: ".ttf, .otf, .woff, .woff2") {
            FileRule(
                name: "Fonts",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "ttf"),
                    MatchCondition(kind: .fileExtension, value: "otf"),
                    MatchCondition(kind: .fileExtension, value: "woff"),
                    MatchCondition(kind: .fileExtension, value: "woff2")
                ],
                conditionLogic: .any,
                destinationSubpath: "Fonts"
            )
        },
        RulePreset(title: "Disk images", subtitle: ".iso, .img (distinct from .dmg installers)") {
            FileRule(
                name: "Disk Images",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "iso"),
                    MatchCondition(kind: .fileExtension, value: "img")
                ],
                conditionLogic: .any,
                destinationSubpath: "Downloads/Disk Images"
            )
        },
        RulePreset(title: "Design files", subtitle: ".sketch, .fig, .xd, .psd, .ai") {
            FileRule(
                name: "Design Files",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "sketch"),
                    MatchCondition(kind: .fileExtension, value: "fig"),
                    MatchCondition(kind: .fileExtension, value: "xd"),
                    MatchCondition(kind: .fileExtension, value: "psd"),
                    MatchCondition(kind: .fileExtension, value: "ai")
                ],
                conditionLogic: .any,
                destinationSubpath: "Design"
            )
        },
        RulePreset(title: "Data files", subtitle: ".csv, .json, .xml") {
            FileRule(
                name: "Data Files",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "csv"),
                    MatchCondition(kind: .fileExtension, value: "json"),
                    MatchCondition(kind: .fileExtension, value: "xml")
                ],
                conditionLogic: .any,
                destinationSubpath: "Documents/Data"
            )
        },
        RulePreset(title: "Torrents", subtitle: ".torrent") {
            FileRule(
                name: "Torrents",
                conditions: [MatchCondition(kind: .fileExtension, value: "torrent")],
                destinationSubpath: "Downloads/Torrents"
            )
        }
    ]

    static func blank() -> FileRule {
        FileRule(
            name: "New Rule",
            conditions: [MatchCondition(kind: .fileExtension, value: "")],
            destinationSubpath: "New Folder"
        )
    }
}
