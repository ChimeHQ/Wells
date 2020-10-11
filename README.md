# Wells
A lightweight diagnostics report submission system

## Integration

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/Wells.git")
]
```

## Getting Started

Wells is just a submission system, and tries not to make any assumptions about the source or contents of the reports it transmits. It contains two main components: `WellsReporter` and `WellsUploader`. By default, these work together. But, `WellsUploader` can be used seperately if you need more control over the process.

Because of it's flexibility, Wells requires you to do a little more work to wire it up to your source of diagnostic data. Here's what an simple setup could look like. Keep in mind that Wells uploads data using NSURLSession background uploads. This means that the start and end of an upload may not occur during the same application launch.

```swift
import Foundation
import Wells

class MyDiagnosticReporter {
    private let reporter: WellsReporter

    init() {
        self.reporter = WellsReporter()

        reporter.delegate = self
    }

    func start() throws {
        // submit files, including an identifier unique to each file
        let logURLs = getExistingLogs()

        for url in logURLs {
            let logIdentifier = computeUniqueIdentifier(for: url)
            let request = makeURLRequest()

            try reporter.submit(fileURL: url, identifier: logIdentifier, uploadRequest: request)
        }

        // or, just submit bytes
        let dataList = getExistingData()

        for data in dataList {
            let request = makeURLRequest()
            reporter.submit(data, uploadRequest: request)
        }

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

## Namesake

Wells is all about reporting, so it seemed logical to name it after a [notable journalist](https://en.wikipedia.org/wiki/Ida_B._Wells).

## Suggestions or Feedback

We'd love to hear from you! Get in touch via [twitter](https://twitter.com/chimehq), an issue, or a pull request.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.