import Foundation
import WidgetKit

struct WidgetSummaryRepository {
    func write(summary: WidgetSummary) throws {
        try WidgetSummaryStore.save(summary)
    }

    func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "DataViewUsageWidget")
    }
}
