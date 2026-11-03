import SwiftUI
import MetalKit
import OSLog

/// このスタート画面だけの描画。Texture/Pipeline/QueueはCoordinatorの寿命中に一度だけ作る。
struct StartSurfaceWaterView: UIViewRepresentable {
    let isActive: Bool

    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.colorPixelFormat = .bgra8Unorm
        (view.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColor(red: 0.01, green: 0.28, blue: 0.62, alpha: 1)
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 30
        view.isUserInteractionEnabled = false
        view.delegate = context.coordinator
        context.coordinator.setActive(isActive, view: view)
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.setActive(isActive, view: view)
    }
    static func dismantleUIView(_ view: MTKView, coordinator: Renderer) {
        coordinator.setActive(false, view: view)
        view.delegate = nil
        view.releaseDrawables()
    }

    final class Renderer: NSObject, MTKViewDelegate {
        let device = MTLCreateSystemDefaultDevice()
        private var queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var texture: MTLTexture?
        private var clock = StartSurfaceClock()
        private let inFlight = DispatchSemaphore(value: 2)
        private struct Uniforms {
            var resolution: SIMD2<Float>
            var seconds: Float
        }

        override init() {
            super.init()
            do {
                guard let device, let image = UIImage(named: "start_water_surface")?.cgImage,
                      let queue = device.makeCommandQueue() else { throw SetupError.unavailable }
                self.queue = queue
                let library = try device.makeDefaultLibrary(bundle: .main)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "startSurfaceVertex")
                descriptor.fragmentFunction = library.makeFunction(name: "startSurfaceFragment")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
                texture = try MTKTextureLoader(device: device).newTexture(cgImage: image, options: [
                    .SRGB: false, .origin: MTKTextureLoader.Origin.topLeft.rawValue,
                    .generateMipmaps: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue
                ])
            } catch {
                Logger(subsystem: "PomodoroAquarium", category: "StartSurface").error("Water setup failed: \(String(describing: error), privacy: .public)")
            }
        }
        private enum SetupError: Error { case unavailable }

        func setActive(_ active: Bool, view: MTKView) {
            let shouldRun = active && pipeline != nil && texture != nil
            let changed = clock.isRunning != shouldRun
            clock.setRunning(shouldRun)
            view.isPaused = !shouldRun
            view.enableSetNeedsDisplay = !shouldRun
            if changed || !shouldRun { view.setNeedsDisplay() }
        }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if view.isPaused { view.setNeedsDisplay() }
        }
        func draw(in view: MTKView) {
            guard let pipeline, let texture, let queue,
                  view.drawableSize.width > 0, view.drawableSize.height > 0,
                  inFlight.wait(timeout: .now()) == .success else { return }
            guard let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor,
                  let command = queue.makeCommandBuffer(),
                  let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
                inFlight.signal()
                return
            }
            let seconds = clock.advance(at: CACurrentMediaTime())
            var uniforms = Uniforms(resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                                    seconds: Float(seconds))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            let gate = inFlight
            command.addCompletedHandler { _ in gate.signal() }
            command.present(drawable)
            command.commit()
        }
    }
}
