import Foundation
import os

#if canImport(MetricKit)
import MetricKit
#endif

/// Point d'entrée unique du monitoring. Aucune dépendance tierce, aucun réseau.
///
/// Trois sources, toutes de première partie :
/// 1. **MetricKit** — crashs, hangs, temps de lancement, énergie. Livré par le système, au plus
///    une fois par jour, sans code d'envoi.
/// 2. **`os.Logger`** — journalisation unifiée, lisible dans Console.app et dans les sysdiagnose.
/// 3. **`DiagnosticLog`** — tampon local consultable dans l'app, pour les incidents applicatifs.
///
/// La remontée vers le développeur passe par **Xcode Organizer**, qui agrège les rapports des
/// utilisateurs ayant accepté de partager leurs analyses avec les développeurs. Voir MONITORING.md.
public final class DiagnosticsCenter: NSObject, @unchecked Sendable {
    public static let shared = DiagnosticsCenter()

    private let lock = NSLock()
    private var _log = DiagnosticLog()

    private let logger = Logger(subsystem: DiagnosticsCenter.subsystem, category: "diagnostics")
    public static let subsystem = "com.duogames.app"

    public var log: DiagnosticLog {
        lock.lock(); defer { lock.unlock() }
        return _log
    }

    // MARK: - Enregistrement

    public func record(
        _ severity: DiagnosticSeverity,
        category: String,
        _ message: String
    ) {
        let event = DiagnosticEvent(severity: severity, category: category, message: message)

        lock.lock()
        _log.record(event)
        lock.unlock()

        switch severity {
        case .info: logger.info("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .warning: logger.warning("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .error, .crash: logger.error("[\(category, privacy: .public)] \(message, privacy: .public)")
        }
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        _log.clear()
    }

    // MARK: - MetricKit

    /// À appeler une fois au démarrage de l'app.
    public func start() {
        #if canImport(MetricKit) && !os(macOS)
        MXMetricManager.shared.add(self)
        record(.info, category: "diagnostics", "MetricKit actif")
        #else
        record(.info, category: "diagnostics", "MetricKit indisponible sur cette plateforme")
        #endif
    }

    public func stop() {
        #if canImport(MetricKit) && !os(macOS)
        MXMetricManager.shared.remove(self)
        #endif
    }
}

#if canImport(MetricKit) && !os(macOS)
extension DiagnosticsCenter: MXMetricManagerSubscriber {

    public func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                // PRD §10.7 : premier coup jouable en moins de 30 s. Le temps de lancement
                // en est la première brique, on le surveille.
                let median = launch.histogrammedTimeToFirstDraw.bucketEnumerator
                    .compactMap { $0 as? MXHistogramBucket<UnitDuration> }
                    .first?.bucketStart.value
                if let median {
                    record(.info, category: "launch", "Temps au premier rendu (1er bucket) : \(median) s")
                }
            }
        }
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let reason = crash.terminationReason ?? "raison inconnue"
                record(.crash, category: "crash", "Crash : \(reason)")
            }
            for hang in payload.hangDiagnostics ?? [] {
                record(.error, category: "hang", "Blocage de \(hang.hangDuration.value) s")
            }
            for crash in payload.appLaunchDiagnostics ?? [] {
                record(.warning, category: "launch", "Lancement lent : \(crash.launchDuration.value) s")
            }
        }
    }
}
#endif
