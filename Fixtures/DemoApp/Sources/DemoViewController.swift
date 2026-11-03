import UIKit
import FSPagerView

/// Scenario selected by launch arguments, e.g. `-container stack -collapse width -direction vertical -infinite 1`.
struct DemoConfiguration {
    enum Container: String {
        case autolayout, stack
    }

    enum Axis: String {
        case width, height
    }

    var container = Container.autolayout
    var collapse = Axis.height
    var direction = FSPagerView.ScrollDirection.horizontal
    var isInfinite = false

    static func fromLaunchArguments() -> DemoConfiguration {
        let defaults = UserDefaults.standard
        var configuration = DemoConfiguration()
        if let container = defaults.string(forKey: "container").flatMap(Container.init(rawValue:)) {
            configuration.container = container
        }
        if let collapse = defaults.string(forKey: "collapse").flatMap(Axis.init(rawValue:)) {
            configuration.collapse = collapse
        }
        if defaults.string(forKey: "direction") == "vertical" {
            configuration.direction = .vertical
        }
        configuration.isInfinite = defaults.bool(forKey: "infinite")
        return configuration
    }
}

final class DemoViewController: UIViewController, FSPagerViewDataSource, FSPagerViewDelegate {
    static let numberOfPages = 5
    static let pagerLength: CGFloat = 200

    private let configuration: DemoConfiguration
    private let pagerView = FSPagerView()
    private let pageControl = FSPageControl()
    private let statusLabel = UILabel()
    private let colors: [UIColor] = [.systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple]
    private var expandedConstraints: [NSLayoutConstraint] = []
    private var collapsedConstraints: [NSLayoutConstraint] = []
    private var state = "expanded"

    init(configuration: DemoConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        pagerView.register(FSPagerViewCell.self, forCellWithReuseIdentifier: "cell")
        pagerView.dataSource = self
        pagerView.delegate = self
        pagerView.scrollDirection = configuration.direction
        pagerView.isInfinite = configuration.isInfinite
        pagerView.accessibilityIdentifier = "pager"
        pagerView.translatesAutoresizingMaskIntoConstraints = false

        let controls = makeControls()
        view.addSubview(controls)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
        ])
        switch configuration.container {
        case .autolayout:
            installWithConstraints(below: controls)
        case .stack:
            installInStackView(below: controls)
        }

        pageControl.numberOfPages = Self.numberOfPages
        pageControl.setFillColor(.label, for: .selected)
        pageControl.setFillColor(.tertiaryLabel, for: .normal)
        pageControl.accessibilityIdentifier = "pageControl"
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            pageControl.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            pageControl.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            pageControl.heightAnchor.constraint(equalToConstant: 30),
        ])
        updateStatus()
    }

    // MARK: - Layout

    private func makeControls() -> UIStackView {
        statusLabel.accessibilityIdentifier = "status"
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 0

        let buttons = UIStackView(arrangedSubviews: [
            makeButton("Next", identifier: "next") { [weak self] in self?.showNextPage() },
            makeButton("Collapse", identifier: "collapse") { [weak self] in self?.setCollapsed(true) },
            makeButton("Expand", identifier: "expand") { [weak self] in self?.setCollapsed(false) },
        ])
        buttons.spacing = 8
        buttons.distribution = .fillEqually

        let controls = UIStackView(arrangedSubviews: [statusLabel, buttons])
        controls.axis = .vertical
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false
        return controls
    }

    private func makeButton(_ title: String, identifier: String, action: @escaping @MainActor () -> Void) -> UIButton {
        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = title
        let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { _ in action() })
        button.accessibilityIdentifier = identifier
        return button
    }

    /// The pager owns its size constraints; collapsing swaps them for a zero-length constraint.
    private func installWithConstraints(below controls: UIView) {
        view.addSubview(pagerView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            pagerView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 16),
            pagerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
        ])
        switch configuration.collapse {
        case .height:
            NSLayoutConstraint.activate([pagerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16)])
            expandedConstraints = [pagerView.heightAnchor.constraint(equalToConstant: Self.pagerLength)]
            collapsedConstraints = [pagerView.heightAnchor.constraint(equalToConstant: 0)]
        case .width:
            NSLayoutConstraint.activate([pagerView.heightAnchor.constraint(equalToConstant: Self.pagerLength)])
            expandedConstraints = [pagerView.widthAnchor.constraint(equalTo: guide.widthAnchor, constant: -32)]
            collapsedConstraints = [pagerView.widthAnchor.constraint(equalToConstant: 0)]
        }
        NSLayoutConstraint.activate(expandedConstraints)
    }

    /// The pager is an arranged subview; collapsing hides it and the stack view removes its length.
    private func installInStackView(below controls: UIView) {
        let before = makeNeighbourLabel("Before")
        let after = makeNeighbourLabel("After")
        let stack = UIStackView(arrangedSubviews: [before, pagerView, after])
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 16)])
        // Priority 999 lets the stack view's own hiding constraint win.
        let height = pagerView.heightAnchor.constraint(equalToConstant: Self.pagerLength)
        height.priority = .init(999)
        switch configuration.collapse {
        case .height:
            stack.axis = .vertical
            let width = pagerView.widthAnchor.constraint(equalTo: stack.widthAnchor)
            width.priority = .init(999)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
                height,
                width,
            ])
        case .width:
            stack.axis = .horizontal
            let width = pagerView.widthAnchor.constraint(equalTo: guide.widthAnchor, multiplier: 0.6)
            width.priority = .init(999)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 16),
                height,
                width,
            ])
        }
    }

    private func makeNeighbourLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    // MARK: - Actions

    private func showNextPage() {
        pagerView.scrollToItem(at: (pagerView.currentIndex + 1) % Self.numberOfPages, animated: true)
    }

    private func setCollapsed(_ collapsed: Bool) {
        let target = collapsed ? "collapsed" : "expanded"
        guard state == "expanded" || state == "collapsed", state != target else {
            return
        }
        state = collapsed ? "collapsing" : "expanding"
        updateStatus()
        UIView.animate(withDuration: 0.3, animations: {
            switch self.configuration.container {
            case .autolayout:
                NSLayoutConstraint.deactivate(collapsed ? self.expandedConstraints : self.collapsedConstraints)
                NSLayoutConstraint.activate(collapsed ? self.collapsedConstraints : self.expandedConstraints)
            case .stack:
                self.pagerView.isHidden = collapsed
            }
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.state = target
            self.updateStatus()
        })
    }

    private func updateStatus() {
        statusLabel.text = "index=\(pagerView.currentIndex) state=\(state)"
        pageControl.currentPage = pagerView.currentIndex
    }

    // MARK: - FSPagerViewDataSource

    func numberOfItems(in pagerView: FSPagerView) -> Int {
        Self.numberOfPages
    }

    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index)
        cell.contentView.backgroundColor = colors[index % colors.count]
        cell.textLabel?.text = "Page \(index)"
        return cell
    }

    // MARK: - FSPagerViewDelegate

    func pagerViewDidScroll(_ pagerView: FSPagerView) {
        updateStatus()
    }

    func pagerViewDidEndScrollAnimation(_ pagerView: FSPagerView) {
        updateStatus()
    }
}
