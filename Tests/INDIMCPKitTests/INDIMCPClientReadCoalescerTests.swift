import Testing

@testable import INDIMCPKit

/// Exercises `INDIMCPClient.ReadCoalescer` in isolation — the piece that keeps
/// `subscribeToResourceUpdates`'s re-reads serialized so a burst of notifications can't run
/// concurrent, unordered reads (see that type's own doc comment for the property-regression risk
/// this prevents). Pure actor state with no network dependency, so this needs neither a live
/// server nor a fake transport.
@Suite("INDIMCPClient.ReadCoalescer")
struct INDIMCPClientReadCoalescerTests {
    @Test func firstCallerShouldStartReading() async {
        let coalescer = INDIMCPClient.ReadCoalescer()
        #expect(await coalescer.shouldStartReading() == true)
    }

    @Test func aSecondCallerWhileOneIsInFlightShouldNotStartReading() async {
        let coalescer = INDIMCPClient.ReadCoalescer()
        #expect(await coalescer.shouldStartReading() == true)
        #expect(await coalescer.shouldStartReading() == false)
    }

    @Test func finishingWithNoRereadRequestedEndsTheCoalescingRun() async {
        let coalescer = INDIMCPClient.ReadCoalescer()
        _ = await coalescer.shouldStartReading()

        #expect(await coalescer.finishedReading() == false)
        // The run ended — a fresh caller should be able to start a new one.
        #expect(await coalescer.shouldStartReading() == true)
    }

    @Test func aNotificationArrivingMidReadIsFoldedIntoOneFollowUpRead() async {
        let coalescer = INDIMCPClient.ReadCoalescer()
        _ = await coalescer.shouldStartReading()

        // Two more notifications arrive while the first read is still in flight.
        #expect(await coalescer.shouldStartReading() == false)
        #expect(await coalescer.shouldStartReading() == false)

        // Both collapse into exactly one follow-up read, not two.
        #expect(await coalescer.finishedReading() == true)
        #expect(await coalescer.finishedReading() == false)
    }
}
