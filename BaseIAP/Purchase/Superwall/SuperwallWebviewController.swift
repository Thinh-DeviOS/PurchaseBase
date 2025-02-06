//
//  SuperwallWebviewController.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import UIKit
import WebKit

class SuperwallWebviewController: UIViewController {
    private var webView = WKWebView()
    private var backButton = UIButton()
    private var titleLabel = UILabel()
    var titleText: String?
    var webUrl: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        webView.load(url: webUrl)
    }
    
    private func setupViews() {
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(webView)
        
        let configuration = UIImage.SymbolConfiguration(font: .boldSystemFont(ofSize: 20))
        let image = UIImage(systemName: "chevron.backward", withConfiguration: configuration)
        backButton.setImage(image, for: .normal)
        backButton.addTarget(self, action: #selector(didTapBackButton), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = titleText
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Back button constraints
            backButton.heightAnchor.constraint(equalToConstant: 44),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            
            // Title label constraints
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            
            // WebView constraints
            webView.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc
    private func didTapBackButton() {
        dismiss(animated: true)
    }
}

extension WKWebView {
    func load(url: URL?) {
        guard let url else { return }
        load(URLRequest(url: url))
    }
}
