<div align="center">

[![Platforms][platforms badge]][platforms]
[![Discord][discord badge]][discord]

</div>

# Wells
A lightweight diagnostics report submission system. 

## Integration

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/Wells")
]
```

## Getting Started

Wells is just a submission system, and tries not to make any assumptions about the source or contents of the reports it transmits. It contains two main components: `WellsReporter` and `WellsUploader`. By default, these work together. But, `WellsUploader` can be used separately if you need more control over the process.

Because of its flexibility, Wells requires you to do a little more work to wire it up to your source of diagnostic data. Here's what an simple setup could look like. Keep in mind that Wells uploads data using `NSURLSession` background uploads. This means that the start and end of an upload may not occur during the same application launch.

If you use `WellsReporter` to submit data, it will manage the cross-launch details itself. But, if you need more control, or want to manage the on-disk files yourself, you'll need to provide it with a `ReportLocationProvider` that can map identifiers back to file URLs.

```swift
import Foundation
import Wells

class MyDiagnosticReporter {
    private let reporter: WellsReporter

    init() {
        self.reporter = WellsReporter()
        
        reporter.existingLogHandler = { url, date in
            // might want to examine date to see how old
            // the date is (and handle errors more gracefully)
            try? submit(url: url)
        }
    }

    func start() throws {
        // submit files, including an identifier unique to each file
        let logURLs = getExistingLogs()

        for url in logURLs {
            try submit(url: url)
        }

        // or, just submit bytes
        let dataList = getExistingData()

        for data in dataList {
            let request = makeURLRequest()
            reporter.submit(data, uploadRequest: request)
        }

    }

    func submit(url: URL) throws {
        let logIdentifier = computeUniqueIdentifier(for: url)
        let request = makeURLRequest()

        try reporter.submit(fileURL: url, identifier: logIdentifier, uploadRequest: request)
    }

    func computeUniqueIdentifier(for url: URL) -> String {
        // this works, but a more robust solution would be based on the content of the data. Note that
        // the url itself *may not* be consistent from launch to launch.
        return UUID().uuidString
    }

    // Finding logs/data is up to you
    func getExistingLogs() -> [URL] {
        return []
    }

    func getExistingData() -> [Data] {
        return []
    }

    func makeURLRequest() -> URLRequest {
        // You have control over the URLRequest that Wells uses. However,
        // some additional metadata will be added to enablee cross-launch tracking.
        let endpoint = URL(string: "https://mydiagnosticservice.com")!

        var request = URLRequest(url: endpoint)

        request.httpMethod = "PUT"
        request.addValue("hiya", forHTTPHeaderField: "custom-header")

        return request
    }
}
```

## Retries

Because that Wells manages submissions *across* app launches, retry logic can be complex. Wells will do its best to retry unsuccesful submissions. It respects the `Retry-After` HTTP header and has backoff. But, it is possible that the hosting app is terminated while a backoff delay is pending. In this situation, `WellsReporter` relies on its `existingLogHandler` property to avoid needing persistent storage.

By default, if there are files found within the `baseURL` directory that are older than 2 days, Wells will give up and delete them.

Bottom line: Wells submissions are best effort. Robust retry support means you have to make use of `existingLogHandler`. There are pathological, if improbable situations that could prevent the submission and retry system from working in a predictable way.

## Using With MetricKit

Wells works great for submitting data gathered from MetricKit. In fact, [MeterReporter](https://github.com/ChimeHQ/MeterReporter) uses it for a full MetricKit-based reporting system.

But, you can also do it yourself. Here's a simple example.

```swift
import Foundation
import MetricKit
import Wells

class MetricKitOnlyReporter: NSObject {
    private let reporter: WellsReporter
    private let endpoint = URL(string: "https://mydiagnosticservice.com")!

    override init() {
        self.reporter = WellsReporter()

        super.init()

        MXMetricManager.shared.add(self)
    }

    private func submitData(_ data: Data) {
        var request = URLRequest(url: endpoint)

        request.httpMethod = "PUT"

        // ok, yes, I have glossed over error handling
        try? reporter.submit(data, uploadRequest: request)
    }
}

extension MetricKitOnlyReporter: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        payloads.map({ $0.jsonRepresentation() }).forEach({ submitData($0) })
    }
}
```

## Namesake

Wells is all about reporting, so it seemed logical to name it after a [notable journalist](https://en.wikipedia.org/wiki/Ida_B._Wells).

## Suggestions or Feedback

I would love to hear from you! Issues or pull requests work great. A [Discord server][discord] is also available for live help, but I have a strong bias towards answering in the form of documentation.

I prefer collaboration, and would love to find ways to work together if you have a similar project.

I prefer indentation with tabs for improved accessibility. But, I'd rather you use the system you want and make a PR than hesitate because of whitespace.

By participating in this project you agree to abide by the [Contributor Code of Conduct](CODE_OF_CONDUCT.md).

[platforms]: https://swiftpackageindex.com/ChimeHQ/Wells
[platforms badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FChimeHQ%2FWells%2Fbadge%3Ftype%3Dplatforms
[discord]: https://discord.gg/esFpX6sErJ
[discord badge]: https://img.shields.io/badge/Discord-purple?logo=Discord&label=Chat&color=%235A64EC
