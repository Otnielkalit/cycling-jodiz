//
//  RouteHubNavigationBarHost.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI
import UIKit

final class RouteHubNavigationBarController: UIViewController {
    private var didApply = false
    private var savedStandard: UINavigationBarAppearance?
    private var savedScrollEdge: UINavigationBarAppearance?
    private var savedCompact: UINavigationBarAppearance?
    private var savedTint: UIColor?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.applyTransparentNavigationBarIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            restoreNavigationBar()
        }
    }

    private func applyTransparentNavigationBarIfNeeded() {
        guard !didApply, let nav = navigationController else { return }
        didApply = true
        savedStandard = nav.navigationBar.standardAppearance
        savedScrollEdge = nav.navigationBar.scrollEdgeAppearance
        savedCompact = nav.navigationBar.compactAppearance
        savedTint = nav.navigationBar.tintColor

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]

        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        nav.navigationBar.compactScrollEdgeAppearance = appearance
        nav.navigationBar.isTranslucent = true
        nav.navigationBar.tintColor = .white
    }

    private func restoreNavigationBar() {
        guard didApply, let nav = navigationController else { return }
        didApply = false
        if let savedStandard {
            nav.navigationBar.standardAppearance = savedStandard
        }
        if let savedScrollEdge {
            nav.navigationBar.scrollEdgeAppearance = savedScrollEdge
        }
        nav.navigationBar.compactAppearance = savedCompact
        nav.navigationBar.compactScrollEdgeAppearance = savedCompact
        nav.navigationBar.tintColor = savedTint
        savedStandard = nil
        savedScrollEdge = nil
        savedCompact = nil
        savedTint = nil
    }
}

struct RouteHubNavigationBarHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RouteHubNavigationBarController {
        let c = RouteHubNavigationBarController()
        c.view.isUserInteractionEnabled = false
        c.view.backgroundColor = .clear
        return c
    }

    func updateUIViewController(_ uiViewController: RouteHubNavigationBarController, context: Context) {}
}
