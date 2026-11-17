import AudioToolbox
import Combine
import CoreAudio
import Foundation

@MainActor
final class VolumeSensor: ObservableObject {
    static let shared = VolumeSensor()

    @Published private(set) var percent = 0
    @Published private(set) var muted = false
    @Published private(set) var deviceName = ""
    @Published private(set) var level: Double = 0
    let changes = PassthroughSubject<Void, Never>()
    private var hasRead = false
    private static let levelTolerance = 1e-4

    private var device = AudioObjectID(kAudioObjectUnknown)
    private lazy var onChange: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        Task { @MainActor in self?.read() }
    }
    private lazy var onDeviceChange: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        Task { @MainActor in self?.attach() }
    }

    private static let watched = [
        address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput),
        address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput),
    ]
    private static let defaultOutput = address(kAudioHardwarePropertyDefaultOutputDevice)

    private init() {
        var defaultOutput = Self.defaultOutput
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutput, .main, onDeviceChange)
        attach()
    }

    func set(percent: Int) {
        set(level: Double(percent) / 100)
    }

    func set(level: Double) {
        if muted { toggleMute() }
        var value = Float32(min(max(level, 0), 1))
        var address = Self.watched[0]
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    func toggleMute() {
        var value: UInt32 = muted ? 0 : 1
        var address = Self.watched[1]
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private func attach() {
        for var address in Self.watched where device != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(device, &address, .main, onChange)
        }
        var address = Self.defaultOutput
        device = Self.value(AudioObjectID(kAudioObjectSystemObject), &address, as: AudioObjectID.self) ?? AudioObjectID(kAudioObjectUnknown)
        for var address in Self.watched {
            AudioObjectAddPropertyListenerBlock(device, &address, .main, onChange)
        }
        var nameAddress = Self.address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        if AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &size, &name) == noErr, let name {
            deviceName = name.takeRetainedValue() as String
        }
        read()
    }

    private func read() {
        var volume = Self.watched[0]
        var mute = Self.watched[1]
        let newLevel = Double(Self.value(device, &volume, as: Float32.self) ?? 0)
        let newMuted = (Self.value(device, &mute, as: UInt32.self) ?? 0) != 0
        let changed = abs(newLevel - level) > Self.levelTolerance || newMuted != muted
        level = newLevel
        percent = Int((newLevel * 100).rounded())
        muted = newMuted
        if hasRead && changed { changes.send() }
        hasRead = true
    }

    private static func value<T>(_ object: AudioObjectID, _ address: inout AudioObjectPropertyAddress, as: T.Type) -> T? {
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private static func address(
        _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
