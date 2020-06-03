//
//  Renderer.swift
//  Obj-macOS
//
//  Created by Reza Ali on 5/23/20.
//  Copyright © 2020 Hi-Rez. All rights reserved.
//

import Metal
import MetalKit
import ModelIO

import Forge
import Satin

class Renderer: Forge.Renderer {
    lazy var context: Context = {
        Context(device, sampleCount, colorPixelFormat, depthPixelFormat, stencilPixelFormat)
    }()
    
    lazy var camera: ArcballPerspectiveCamera = {
        let camera = ArcballPerspectiveCamera()
        camera.position = simd_make_float3(0.0, 0.0, 9.0)
        camera.near = 0.001
        camera.far = 100.0
        return camera
    }()
    
    lazy var cameraController: ArcballCameraController = {
        ArcballCameraController(camera: camera, view: mtkView, defaultPosition: camera.position, defaultOrientation: camera.orientation)
    }()
    
    var scene = Object()
    
    lazy var renderer: Satin.Renderer = {
        Satin.Renderer(context: context, scene: scene, camera: camera)
    }()
    
    #if os(macOS) || os(iOS)
    lazy var raycaster: Raycaster = {
        Raycaster(context: context)
    }()
    #endif
    
    required init?(metalKitView: MTKView) {
        super.init(metalKitView: metalKitView)
    }
    
    override func setupMtkView(_ metalKitView: MTKView) {
        metalKitView.sampleCount = 8
        metalKitView.depthStencilPixelFormat = .depth32Float
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            metalKitView.preferredFramesPerSecond = 120
        case .phone:
            metalKitView.preferredFramesPerSecond = 60
        case .unspecified:
            metalKitView.preferredFramesPerSecond = 60
        case .tv:
            metalKitView.preferredFramesPerSecond = 60
        case .carPlay:
            metalKitView.preferredFramesPerSecond = 60
        @unknown default:
            metalKitView.preferredFramesPerSecond = 60
        }
        #else
        metalKitView.preferredFramesPerSecond = 60
        #endif
    }
    
    override func setup() {
        loadOBJ()
//        loadUSD()
        setupRenderer()
    }
    
    func loadOBJ() {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Assets/suzanne.obj") else { return }
        
        let asset = MDLAsset(url: url, vertexDescriptor: SatinModelIOVertexDescriptor(), bufferAllocator: MTKMeshBufferAllocator(device: context.device))
        let mesh = Mesh(geometry: Geometry(), material: NormalColorMaterial())
        mesh.label = "Suzanne"
        
        let geo = mesh.geometry
        let object0 = asset.object(at: 0)
        if let objMesh = object0 as? MDLMesh {
            let vertexData = objMesh.vertexBuffers[0].map().bytes.bindMemory(to: Vertex.self, capacity: objMesh.vertexCount)
            geo.vertexData = Array(UnsafeBufferPointer(start: vertexData, count: objMesh.vertexCount))
            geo.vertexBuffer = (objMesh.vertexBuffers[0] as! MTKMeshBuffer).buffer
            guard let submeshes = objMesh.submeshes, let first = submeshes.firstObject, let sub: MDLSubmesh = first as? MDLSubmesh else { return }
            let indexDataPtr = sub.indexBuffer(asIndexType: .uInt32).map().bytes.bindMemory(to: UInt32.self, capacity: sub.indexCount)
            let indexData = Array(UnsafeBufferPointer(start: indexDataPtr, count: sub.indexCount))
            geo.indexData = indexData
            geo.indexBuffer = (sub.indexBuffer as! MTKMeshBuffer).buffer
        }
        
        scene.add(mesh)
    }
    
    func setupRenderer() {
        renderer = Satin.Renderer(context: context, scene: scene, camera: camera)
    }
    
    func loadUSD() {
        let fileName = "flower_tulip"
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Assets/\(fileName).usdz") else { return }
        let asset = MDLAsset(url: url, vertexDescriptor: SatinModelIOVertexDescriptor(), bufferAllocator: MTKMeshBufferAllocator(device: context.device))
        scene = Object()
        let object = asset.object(at: 0)
        print(object.name)
        scene.label = object.name
        if let transform = object.transform {
            scene.localMatrix = transform.matrix
        }
        loadChildren(scene, object.children.objects)
    }
    
    func loadChildren(_ parent: Object, _ children: [MDLObject]) {
        for child in children {
            if let mdlMesh = child as? MDLMesh {
                let geometry = Geometry()
                let mesh = Mesh(geometry: geometry, material: NormalColorMaterial())
                mesh.label = child.name
                parent.add(mesh)
                
                let vertexData = mdlMesh.vertexBuffers[0].map().bytes.bindMemory(to: Vertex.self, capacity: mdlMesh.vertexCount)
                geometry.vertexData = Array(UnsafeBufferPointer(start: vertexData, count: mdlMesh.vertexCount))
                geometry.vertexBuffer = (mdlMesh.vertexBuffers[0] as! MTKMeshBuffer).buffer
                
                if let mdlSubMeshes = mdlMesh.submeshes {
                    let mdlSubMeshesCount = mdlSubMeshes.count
                    for index in 0..<mdlSubMeshesCount {
                        let mdlSubmesh = mdlSubMeshes[index] as! MDLSubmesh
                        if mdlSubmesh.geometryType == .triangles {
                            let indexCount = mdlSubmesh.indexCount
                            let indexDataPtr = mdlSubmesh.indexBuffer(asIndexType: .uInt32).map().bytes.bindMemory(to: UInt32.self, capacity: indexCount)
                            let indexData = Array(UnsafeBufferPointer(start: indexDataPtr, count: indexCount))
                            let submesh = Submesh(indexData: indexData, indexBuffer: (mdlSubmesh.indexBuffer as! MTKMeshBuffer).buffer)
                            submesh.label = mdlSubmesh.name
                            mesh.addSubmesh(submesh)
                        }
                    }
                }
                
                if let transform = mdlMesh.transform {
                    mesh.localMatrix = transform.matrix
                }
                
                loadChildren(mesh, child.children.objects)
            }
            else {
                let object = Object()
                object.label = child.name
                parent.add(object)
                loadChildren(object, child.children.objects)
            }
        }
    }
    
    override func update() {
        cameraController.update()
        renderer.update()
    }
    
    override func draw(_ view: MTKView, _ commandBuffer: MTLCommandBuffer) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderer.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
    }
    
    override func resize(_ size: (width: Float, height: Float)) {
        camera.aspect = size.width / size.height
        renderer.resize(size)
    }
    
    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let m = event.locationInWindow
        let pt = normalizePoint(m, mtkView.frame.size)
        raycaster.setFromCamera(camera, pt)
        let results = raycaster.intersect(scene)
        for result in results {
            print(result.object.label)
            print(result.position)
        }
    }
    
    #elseif os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let first = touches.first {
            let point = first.location(in: mtkView)
            let size = mtkView.frame.size
            let pt = normalizePoint(point, size)
            raycaster.setFromCamera(camera, pt)
            let results = raycaster.intersect(scene, true)
            for result in results {
                print(result.object.label)
                print(result.position)
            }
        }
    }
    #endif
    
    func normalizePoint(_ point: CGPoint, _ size: CGSize) -> simd_float2 {
        #if os(macOS)
        return 2.0 * simd_make_float2(Float(point.x / size.width), Float(point.y / size.height)) - 1.0
        #else
        return 2.0 * simd_make_float2(Float(point.x / size.width), 1.0 - Float(point.y / size.height)) - 1.0
        #endif
    }
}