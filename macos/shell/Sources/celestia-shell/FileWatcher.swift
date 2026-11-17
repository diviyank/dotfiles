import Foundation

@MainActor
final class FileWatcher {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var retry: Timer?

    init(_ url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        arm()
    }

    private func arm() {
        source?.cancel()
        source = nil
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.arm() }
            }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename, .attrib], queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let replaced = !source.data.isDisjoint(with: [.delete, .rename])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    MainActor.assumeIsolated {
                        if replaced { self.arm() }
                        self.onChange()
                    }
                }
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
