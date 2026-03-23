import Foundation

struct ValidationRunResult {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String

    var succeeded: Bool {
        exitCode == 0
    }

    var combinedOutput: String {
        let stdout = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = standardError.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (stdout.isEmpty, stderr.isEmpty) {
        case (true, true):
            return ""
        case (false, true):
            return stdout
        case (true, false):
            return stderr
        case (false, false):
            return "\(stdout)\n\n\(stderr)"
        }
    }
}

struct ValidationRunnerService {
    private let processRunner: ProcessRunner

    init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    func runValidationScript(at scriptURL: URL, currentDirectoryURL: URL) throws -> ValidationRunResult {
        let result = try processRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: [scriptURL.path],
            currentDirectoryURL: currentDirectoryURL
        )

        return ValidationRunResult(
            exitCode: result.exitCode,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }
}
