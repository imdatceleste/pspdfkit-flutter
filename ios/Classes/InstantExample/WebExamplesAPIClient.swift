//
//  Copyright © 2017-2020 PSPDFKit GmbH. All rights reserved.
//
//  The PSPDFKit Sample applications are licensed with a modified BSD license.
//  Please see License for details. This notice may not be removed from this file.
//

import Foundation

/// Interfaces with our PSPDFKit for Web examples server.
///
/// This is just networking and JSON parsing. It’s very specific our backend so not very useful as sample code.
/// In your own app you would connect to your own server backend to get Instant document identifiers and authentication tokens.
class WebExamplesAPIClient: NSObject, URLSessionTaskDelegate {

    enum Failure: Error {
        case cancelled
        case invalidCode
        case internalError(underlying: Error?)
    }

    typealias APIResult = Result<InstantDocumentInfo, Error>
    typealias CompletionHandler = (_ result: APIResult) -> Void

    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    private weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
        super.init()
    }

    /// Starts a new collaboration group. The completion handler may be called on a background thread.
    func createNewSession(completion: @escaping CompletionHandler) {
        var request = URLRequest(url: URL(string: "https://web-examples.pspdfkit.com/api/instant-landing-page")!)
        request.httpMethod = "POST"

        startDataTask(with: request, completion: completion)
    }

    /// Tries to access an existing collaboration group. The completion handler may be called on a background thread.
    func resolveExistingSessionURL(_ url: URL, completion: @escaping CompletionHandler) {
        var request = URLRequest(url: url)
        request.addValue("application/vnd.instant-example+json", forHTTPHeaderField: "Accept")

        startDataTask(with: request, completion: completion)
    }

    private func startDataTask(with request: URLRequest, completion: @escaping CompletionHandler) {
        let task = session.dataTask(with: request) { data, response, error in
            let result = self.resultFromResponse(with: data, response: response, error: error)
            completion(result)
        }
        task.resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic, challenge.proposedCredential?.password == nil {
            promptForHTTPBasicAuthenticationCredential(challenge: challenge) { providedCredential in
                if let providedCredential = providedCredential {
                    completionHandler(.useCredential, providedCredential)
                } else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            }
        } else {
            completionHandler(.performDefaultHandling, challenge.proposedCredential)
        }
    }

    private func promptForHTTPBasicAuthenticationCredential(challenge: URLAuthenticationChallenge, completion: @escaping (URLCredential?) -> Void) {
        let credential = URLCredential(
            user: "username",
            password: "password",
            persistence: .permanent
        )
        completion(credential)
    }

    private func resultFromResponse(with data: Data?, response: URLResponse?, error: Error?) -> APIResult {
        if let error = error as? URLError {
            switch error.code {
            case .cancelled:
                return .failure(Failure.cancelled)
            default:
                return .failure(Failure.internalError(underlying: error))
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(Failure.internalError(underlying: nil))
        }

        switch httpResponse.statusCode {
        case 200:
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) {
                if let document = InstantDocumentInfo(json: json) {
                    return .success(document)
                }
            }
            return .failure(Failure.internalError(underlying: nil))
        case 400:
            return .failure(Failure.invalidCode)
        default:
            return .failure(Failure.internalError(underlying: nil))
        }
    }
}

extension WebExamplesAPIClient.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The request has been cancelled."
        case .invalidCode:
            return "The document code is invalid."
        case .internalError(let underlying?):
            return "An error occurred: \(underlying)"
        case .internalError(nil):
            return "An internal error occurred."
        }
    }
}
