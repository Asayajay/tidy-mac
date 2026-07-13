import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Lightweight "on file system change" trigger: opens each watched folder and listens
/// for write events via a dispatch source, rather than pulling in the full FSEvents
/// stream API. Good enough to notice "a file appeared/changed here," which is all an
/// organize trigger needs -- it doesn't need to know exactly what changed, since the
/// next scan figures that out from scratch anyway.
final class DirectoryWatcher {
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private let onChange: (URL) -> Void

    init(onChange: @escaping (URL) -> Void) {
        self.onChange = onChange
    }

    func watch(_ urls: [URL]) {
        stopAll()
        for url in urls {
            let fd = open(url.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .main)
            source.setEventHandler { [weak self] in
                self?.onChange(url)
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            sources[url.path] = source
        }
    }

    func stopAll() {
        for (_, source) in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    deinit {
        stopAll()
    }
}
