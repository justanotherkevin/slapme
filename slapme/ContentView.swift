//
//  ContentView.swift
//  slapme
//
//  Created by kevin hu on 3/28/26.
//

import AVFoundation
import CoreMotion
import Observation
import SwiftUI

@MainActor
@Observable
final class MotionAudioDetector {
    var isMonitoring = false
    var lastAcceleration: Double = 0
    var peakAcceleration: Double = 0
    var statusMessage = "Tap Start Monitoring to listen for fast motion."
    var threshold: Double = 2.2

    private let motionManager = CMMotionManager()
    private let tonePlayer = TonePlayer()
    private let minimumTriggerInterval: TimeInterval = 0.75
    private var lastTriggerDate = Date.distantPast

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            statusMessage = "Device motion is unavailable on this device."
            return
        }

        do {
            try tonePlayer.prepare()
        } catch {
            statusMessage = "Couldn't prepare audio playback."
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if error != nil {
                self.statusMessage = "Motion updates stopped unexpectedly."
                self.stopMonitoring()
                return
            }

            guard let motion else { return }

            let acceleration = motion.userAcceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )

            self.lastAcceleration = magnitude
            self.peakAcceleration = max(self.peakAcceleration, magnitude)

            guard magnitude >= self.threshold else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastTriggerDate) >= self.minimumTriggerInterval else {
                return
            }

            self.lastTriggerDate = now
            self.statusMessage = String(format: "Triggered at %.2fg", magnitude)
            self.tonePlayer.play()
        }

        isMonitoring = true
        statusMessage = "Monitoring motion. Shake or move the phone quickly."
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false

        if statusMessage.hasPrefix("Triggered at") {
            statusMessage = "Monitoring stopped."
        } else if statusMessage != "Device motion is unavailable on this device." {
            statusMessage = "Monitoring paused."
        }
    }
}

private final class TonePlayer {
    private var audioPlayer: AVAudioPlayer?

    func prepare() throws {
        try configureAudioSession()

        if let audioPlayer {
            audioPlayer.prepareToPlay()
            return
        }

        let fileURL = try makeToneFile()
        audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
        audioPlayer?.volume = 1.0
        audioPlayer?.prepareToPlay()
    }

    func play() {
        guard let audioPlayer else { return }
        audioPlayer.currentTime = 0
        audioPlayer.play()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: [.mixWithOthers])
        try session.setActive(true)
    }

    private func makeToneFile() throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("slap-alert.wav")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let sampleRate = 44_100
        let duration = 0.18
        let frequency = 880.0
        let sampleCount = Int(Double(sampleRate) * duration)
        var pcmData = Data(capacity: sampleCount * MemoryLayout<Int16>.size)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            let envelope = 1.0 - (Double(sampleIndex) / Double(sampleCount))
            let amplitude = sin(2 * .pi * frequency * time) * 0.45 * envelope
            let sample = Int16(max(-1, min(1, amplitude)) * Double(Int16.max))
            append(sample, to: &pcmData)
        }

        let wavData = makeWAVData(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channelCount: 1,
            bitsPerSample: 16
        )

        try wavData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func makeWAVData(
        pcmData: Data,
        sampleRate: Int,
        channelCount: Int,
        bitsPerSample: Int
    ) -> Data {
        let byteRate = sampleRate * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let riffChunkSize = 36 + pcmData.count

        var data = Data()
        data.append(Data("RIFF".utf8))
        append(UInt32(riffChunkSize), to: &data)
        data.append(Data("WAVE".utf8))
        data.append(Data("fmt ".utf8))
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(channelCount), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(byteRate), to: &data)
        append(UInt16(blockAlign), to: &data)
        append(UInt16(bitsPerSample), to: &data)
        data.append(Data("data".utf8))
        append(UInt32(pcmData.count), to: &data)
        data.append(pcmData)
        return data
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}

struct ContentView: View {
    @State private var detector = MotionAudioDetector()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: detector.isMonitoring ? "waveform.path.ecg" : "iphone.radiowaves.left.and.right")
                    .font(.system(size: 52))
                    .foregroundStyle(detector.isMonitoring ? .red : .blue)

                Text("Slap Me")
                    .font(.largeTitle.bold())

                Text(detector.statusMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                LabeledContent("Current motion") {
                    Text(String(format: "%.2fg", detector.lastAcceleration))
                        .monospacedDigit()
                }

                LabeledContent("Peak motion") {
                    Text(String(format: "%.2fg", detector.peakAcceleration))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger threshold")
                        .font(.headline)

                    Slider(value: $detector.threshold, in: 1.2...4.0, step: 0.1)

                    Text(String(format: "%.1fg", detector.threshold))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

            Button(detector.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                detector.toggleMonitoring()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("This uses iPhone motion data from Core Motion. The GitHub repository you linked targets Apple Silicon Macs, so the phone version uses the public iOS sensor API instead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ContentView()
}
