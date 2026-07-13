import Foundation

/// The out-of-the-box rule set. Fully editable/removable by the user at runtime --
/// this is just a sensible starting point, not a hardcoded assumption.
///
/// Order matters: Screenshots is checked before Images, since a screenshot is also a PNG.
/// If it were listed after Images, every screenshot would get swept into the generic
/// Images folder instead, which is exactly the kind of ordering bug the tests guard against.
public enum DefaultRules {
    public static var all: [FileRule] {
        [
            FileRule(
                name: "Screenshots",
                conditions: [
                    MatchCondition(kind: .filenameRegex, value: "^Screen ?Shot .*"),
                    MatchCondition(kind: .filenameRegex, value: "^CleanShot .*")
                ],
                conditionLogic: .any,
                destinationSubpath: "Screenshots"
            ),
            FileRule(
                name: "PDFs",
                conditions: [MatchCondition(kind: .fileExtension, value: "pdf")],
                destinationSubpath: "Documents/PDFs"
            ),
            FileRule(
                name: "Installers",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "dmg"),
                    MatchCondition(kind: .fileExtension, value: "pkg")
                ],
                destinationSubpath: "Downloads/Installers"
            ),
            FileRule(
                name: "Images",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "jpg"),
                    MatchCondition(kind: .fileExtension, value: "jpeg"),
                    MatchCondition(kind: .fileExtension, value: "png"),
                    MatchCondition(kind: .fileExtension, value: "heic"),
                    MatchCondition(kind: .fileExtension, value: "gif"),
                    MatchCondition(kind: .fileExtension, value: "tiff"),
                    MatchCondition(kind: .fileExtension, value: "webp")
                ],
                destinationSubpath: "Pictures"
            ),
            FileRule(
                name: "Documents",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "doc"),
                    MatchCondition(kind: .fileExtension, value: "docx"),
                    MatchCondition(kind: .fileExtension, value: "xls"),
                    MatchCondition(kind: .fileExtension, value: "xlsx"),
                    MatchCondition(kind: .fileExtension, value: "ppt"),
                    MatchCondition(kind: .fileExtension, value: "pptx"),
                    MatchCondition(kind: .fileExtension, value: "txt"),
                    MatchCondition(kind: .fileExtension, value: "rtf"),
                    MatchCondition(kind: .fileExtension, value: "pages"),
                    MatchCondition(kind: .fileExtension, value: "numbers"),
                    MatchCondition(kind: .fileExtension, value: "key")
                ],
                destinationSubpath: "Documents"
            ),
            FileRule(
                name: "Archives",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "zip"),
                    MatchCondition(kind: .fileExtension, value: "tar"),
                    MatchCondition(kind: .fileExtension, value: "gz"),
                    MatchCondition(kind: .fileExtension, value: "tgz"),
                    MatchCondition(kind: .fileExtension, value: "rar"),
                    MatchCondition(kind: .fileExtension, value: "7z"),
                    MatchCondition(kind: .fileExtension, value: "bz2")
                ],
                destinationSubpath: "Archives"
            ),
            FileRule(
                name: "Audio",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "mp3"),
                    MatchCondition(kind: .fileExtension, value: "wav"),
                    MatchCondition(kind: .fileExtension, value: "m4a"),
                    MatchCondition(kind: .fileExtension, value: "aac"),
                    MatchCondition(kind: .fileExtension, value: "flac")
                ],
                destinationSubpath: "Audio"
            ),
            FileRule(
                name: "Video",
                conditions: [
                    MatchCondition(kind: .fileExtension, value: "mp4"),
                    MatchCondition(kind: .fileExtension, value: "mov"),
                    MatchCondition(kind: .fileExtension, value: "avi"),
                    MatchCondition(kind: .fileExtension, value: "mkv"),
                    MatchCondition(kind: .fileExtension, value: "m4v")
                ],
                destinationSubpath: "Videos"
            )
        ]
    }
}
