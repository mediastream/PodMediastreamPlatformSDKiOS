//
//  RestApiManager.swift
//  Pods
//
//  Created by Adler Oliveira on 6/10/16.
//
//

import Foundation

typealias ServiceResponse = (JSON, [HTTPCookie], NSError?) -> Void

class RestApiManager: NSObject {
    static let sharedInstance = RestApiManager()
    
    func getJSON(_ url: String, onCompletion: @escaping (JSON) -> Void) {
        makeHTTPGetRequest(url, onCompletion: {json, cookies, err in onCompletion(json as JSON)})
    }
    
    func makeHTTPGetRequest(_ path: String, onCompletion: @escaping ServiceResponse) {
        guard let requestUrl = URL(string: path) else {return}
        let request = NSMutableURLRequest(url: requestUrl)
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
            if error != nil {
                print(error!.localizedDescription)
            }
            guard let data = data else {return}
            if let httpResponse = response as? HTTPURLResponse, let fields = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: (response?.url)!)
                HTTPCookieStorage.shared.setCookies(cookies, for: response?.url, mainDocumentURL: nil)
                do {
                    let json:JSON = try JSON(data: data)
                    onCompletion(json, cookies, error as NSError?)
                } catch let jsonError {
                    print(jsonError)
                }
            }
        })
        task.resume()
    }
}
