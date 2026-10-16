import Foundation
import Testing
@testable import Diagnostics

@Suite("Journal d'incidents")
struct IssueLogTests {

    private func issue(_ severity: DiagnosticSeverity, _ message: String = "test", offset: TimeInterval = 0) -> DiagnosticEvent {
        DiagnosticEvent(date: Date(timeIntervalSince1970: 1_000_000 + offset),
              severity: severity, category: "test", message: message)
    }

    @Test("Les sévérités s'ordonnent d'info à crash")
    func severityOrdering() {
        #expect(DiagnosticSeverity.info < .warning)
        #expect(DiagnosticSeverity.warning < .error)
        #expect(DiagnosticSeverity.error < .crash)
        #expect(DiagnosticSeverity.allCases.count == 4)
    }

    @Test("Un incident enregistré est conservé")
    func recordsIssue() {
        var log = DiagnosticLog()
        log.record(issue(.warning, "posture instable"))
        #expect(log.events.count == 1)
        #expect(log.events.first?.message == "posture instable")
    }

    @Test("Le journal ne dépasse jamais sa capacité")
    func respectsCapacity() {
        var log = DiagnosticLog(capacity: 3)
        for index in 0..<10 {
            log.record(issue(.info, "événement \(index)", offset: TimeInterval(index)))
        }
        #expect(log.events.count == 3, "le tampon doit rester borné sur l'appareil du joueur")
        #expect(log.events.first?.message == "événement 7", "les plus anciens sont évincés")
        #expect(log.events.last?.message == "événement 9")
    }

    @Test("Le filtrage par sévérité minimale est inclusif")
    func filtersBySeverity() {
        var log = DiagnosticLog()
        log.record(issue(.info))
        log.record(issue(.warning))
        log.record(issue(.error))
        log.record(issue(.crash))

        #expect(log.filtered(minimum: .info).count == 4)
        #expect(log.filtered(minimum: .warning).count == 3)
        #expect(log.filtered(minimum: .error).count == 2)
        #expect(log.filtered(minimum: .crash).count == 1)
    }

    @Test("Le tri place le plus grave en tête, puis le plus récent")
    func sortsByPriority() {
        var log = DiagnosticLog()
        log.record(issue(.info, "ancien info", offset: 0))
        log.record(issue(.crash, "crash", offset: 1))
        log.record(issue(.info, "récent info", offset: 2))

        let sorted = log.sortedByPriority
        #expect(sorted.first?.message == "crash")
        #expect(sorted[1].message == "récent info", "à sévérité égale, le plus récent d'abord")
    }

    @Test("Un incident bloquant est détecté à partir du niveau erreur")
    func detectsBlockingIssues() {
        var log = DiagnosticLog()
        log.record(issue(.warning))
        #expect(log.hasBlockingEvents == false)

        log.record(issue(.error))
        #expect(log.hasBlockingEvents)
    }

    @Test("Le journal peut être vidé")
    func clears() {
        var log = DiagnosticLog()
        log.record(issue(.error))
        log.clear()
        #expect(log.events.isEmpty)
        #expect(log.hasBlockingEvents == false)
    }

    @Test("Le centre de diagnostic enregistre et expose les incidents")
    func centerRecords() {
        let center = DiagnosticsCenter()
        center.clear()
        center.record(.error, category: "storekit", "restauration échouée")
        #expect(center.log.events.count == 1)
        #expect(center.log.hasBlockingEvents)
        center.clear()
        #expect(center.log.events.isEmpty)
    }
}
