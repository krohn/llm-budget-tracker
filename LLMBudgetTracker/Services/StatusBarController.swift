import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    let viewModel = BudgetViewModel()
    let updateChecker = UpdateChecker()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private weak var hostingViewController: NSViewController?
    private var shimmerTimer: Timer?
    private var shimmerStart: CFTimeInterval = 0
    private var shimmerPhase: CGFloat?
    private static let shimmerSweepSeconds: CFTimeInterval = 1.2

    init() {
        setupPopover()
        setupButton()
        observeViewModel()
        updateChecker.startAutoCheck()
    }

    // MARK: - Setup

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 470, height: 420)
        let controller = NSHostingController(
            rootView: PopoverView(closePopover: { [weak self] in
                self?.popover.performClose(nil)
            })
            .environment(viewModel)
            .environment(updateChecker)
        )
        hostingViewController = controller
        popover.contentViewController = controller
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        updateImage()
    }

    // MARK: - Click

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            viewModel.refreshIfStale()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updatePopoverSize()
            popover.contentViewController?.view.window?.makeKey()
            Task { @MainActor [weak self] in
                self?.popover.contentViewController?.view.window?.makeFirstResponder(nil)
                self?.updatePopoverSize()
            }
        }
    }

    // MARK: - Icon

    private func updateImage() {
        guard let button = statusItem.button else { return }
        let img = progressBarImage(
            progress: viewModel.budgetPercentage,
            color: viewModel.pacingBarNSColor,
            label: viewModel.menuBarText,
            shimmerPhase: shimmerPhase
        )
        img.isTemplate = false
        button.image = img
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = viewModel.menuBarTooltip
        button.setAccessibilityLabel("LLM Budget Tracker")
        button.setAccessibilityValue(accessibilityValue)
        button.setAccessibilityHelp("Open budget overview and settings")
    }

    /// Sweeps a highlight across the pill while a refresh is in flight. The
    /// status item is drawn as an image, so the animation redraws that image.
    private func updateShimmer() {
        guard viewModel.isLoading, shimmerTimer == nil else { return }
        shimmerStart = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.shimmerTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        shimmerTimer = timer
    }

    private func shimmerTick() {
        let sweep = Self.shimmerSweepSeconds
        let previous = (shimmerPhase ?? 0) * sweep
        let elapsed = (CACurrentMediaTime() - shimmerStart).truncatingRemainder(dividingBy: sweep)
        // Finish the current sweep after loading ends so short refreshes stay visible.
        if !viewModel.isLoading && elapsed < previous {
            shimmerTimer?.invalidate()
            shimmerTimer = nil
            shimmerPhase = nil
        } else {
            shimmerPhase = CGFloat(elapsed / sweep)
        }
        updateImage()
    }

    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.budgetPercentage
            _ = viewModel.menuBarText
            _ = viewModel.pacingBarNSColor
            _ = viewModel.menuBarTooltip
            _ = viewModel.appState
            _ = viewModel.isLoading
            _ = viewModel.spendLogs
            _ = updateChecker.status
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateImage()
                self?.updateShimmer()
                self?.updatePopoverSize()
                self?.observeViewModel()
            }
        }
    }

    private func updatePopoverSize() {
        guard let view = hostingViewController?.view else { return }
        let fittedHeight = view.fittingSize.height
        let clampedHeight = min(max(fittedHeight, 320), 900)
        popover.contentSize = NSSize(width: 470, height: clampedHeight)
    }

    private var accessibilityValue: String {
        switch viewModel.appState {
        case .notConfigured:
            return "Not configured"
        case .authError:
            return "Authentication failed"
        case .rateLimited:
            return "Requests paused"
        case .networkError:
            return "Server unreachable"
        case .offline:
            return "Waiting for connection"
        case .invalidData:
            return "Invalid response data"
        case .noBudget:
            return "Used \(viewModel.menuBarText), no budget limit"
        case .unknownError:
            return "Unknown error"
        case .loading:
            return "Loading budget"
        case .refreshing:
            return "Refreshing budget"
        case .loaded:
            return "Used \(viewModel.menuBarText), pacing \(viewModel.pacingStatus.label)"
        }
    }
}

// MARK: - Image Drawing

/// Menu bar pill in the style of SolidtimeBar: dark capsule with an inner segment
/// tinted in the pacing color; the solid-color part of the segment shows progress.
private func progressBarImage(progress: Double, color: NSColor, label: String, shimmerPhase: CGFloat?) -> NSImage {
    let height: CGFloat = 18
    let inset: CGFloat = 2
    let segmentHeight = height - 2 * inset
    let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    // Lightened so the label stays readable on the dark, tinted part of the segment
    let trackText = color.blended(withFraction: 0.35, of: .white) ?? color
    let textOnTrack = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: trackText])
    let textOnFill = NSAttributedString(
        string: label,
        attributes: [.font: font, .foregroundColor: NSColor(white: 0.08, alpha: 1)]
    )
    let textSize = textOnTrack.size()
    let segmentWidth = max(ceil(textSize.width) + 12, 40)
    let width = segmentWidth + 2 * inset

    return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
        NSColor(white: 0.13, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).fill()

        let segment = NSRect(x: inset, y: inset, width: segmentWidth, height: segmentHeight)
        let segmentPath = NSBezierPath(roundedRect: segment, xRadius: segmentHeight / 2, yRadius: segmentHeight / 2)
        color.withAlphaComponent(0.28).setFill()
        segmentPath.fill()

        let textPoint = NSPoint(x: segment.midX - textSize.width / 2, y: segment.midY - textSize.height / 2)
        textOnTrack.draw(at: textPoint)

        // Solid progress fill; the label is redrawn dark inside it to stay readable
        let fillRect = NSRect(
            x: segment.minX, y: segment.minY,
            width: segment.width * CGFloat(min(1, max(0, progress))), height: segment.height
        )
        if fillRect.width > 0 {
            NSGraphicsContext.saveGraphicsState()
            segmentPath.addClip()
            NSBezierPath(rect: fillRect).addClip()
            color.setFill()
            segmentPath.fill()
            textOnFill.draw(at: textPoint)
            NSGraphicsContext.restoreGraphicsState()
        }

        // Loading shimmer
        if let phase = shimmerPhase {
            NSGraphicsContext.saveGraphicsState()
            segmentPath.addClip()
            let bandW = segment.width * 0.45
            let bandX = segment.minX - bandW + (segment.width + bandW) * phase
            let highlight = NSColor.white.withAlphaComponent(0.35)
            NSGradient(colors: [highlight.withAlphaComponent(0), highlight, highlight.withAlphaComponent(0)])?
                .draw(in: CGRect(x: bandX, y: segment.minY, width: bandW, height: segment.height), angle: 0)
            NSGraphicsContext.restoreGraphicsState()
        }
        return true
    }
}
