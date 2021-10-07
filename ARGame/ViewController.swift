//
//  ViewController.swift
//  ARGame
//
//  Created by Stanislav Makushov on 07.10.2021.
//

import UIKit
import ARKit
import RealityKit
import Combine

class ViewController: UIViewController {
    
    let arView = ARView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        setupActions()
        
        initializeObjects()
    }
    
    private func setupARView() {
        arView.frame = UIScreen.main.bounds
        
        let session = arView.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        session.run(config)
        
        // onboarding tips for finding needed plane
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.frame = arView.frame
        arView.addSubview(coachingOverlay)
        
        view.addSubview(arView)
    }
    
    private func setupActions() {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(observeTaps(_:)))
        arView.addGestureRecognizer(gestureRecognizer)
    }
    
    private func initializeObjects() {
        // create an anchor with provided size
        let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.5, 0.5])
        
        // add anchor to scene
        arView.scene.addAnchor(anchor)
        
        // our "virtual cards"
        var cards: [Entity] = []
        
        // creating cards' models
        for _ in 1...16 {
            // small squared box with small height
            let box = MeshResource.generateBox(width: 0.04, height: 0.002, depth: 0.04)
            // let's make our boxes metallic
            let metalMaterial = SimpleMaterial(color: .gray, isMetallic: true)
            // then create box model
            let model = ModelEntity(mesh: box, materials: [metalMaterial])
            
            // generating model for viewing
            model.generateCollisionShapes(recursive: true)
            
            cards.append(model)
        }
        
        // ok, our cards are generated, let's place them to anchor
        for (index, card) in cards.enumerated() {
            let x = Float(index % 4)
            let z = Float(index / 4)
            
            card.position = [x*0.1, 0, z*0.1]
            anchor.addChild(card)
        }
        
        // to hide our models when card is flipped, let's create a box
        let boxSize: Float = 0.7
        let occlusionBoxMesh = MeshResource.generateBox(size: boxSize)
        let occlusionBox = ModelEntity(mesh: occlusionBoxMesh, materials: [OcclusionMaterial()])
        // positioning box under our cards
        occlusionBox.position.y = -boxSize / 2
        anchor.addChild(occlusionBox)
        
        // loading models asyncronously
        var cancellable: AnyCancellable? = nil
        cancellable = ModelEntity.loadModelAsync(named: "01")
            .append(ModelEntity.loadModelAsync(named: "02"))
            .append(ModelEntity.loadModelAsync(named: "03"))
            .append(ModelEntity.loadModelAsync(named: "04"))
            .append(ModelEntity.loadModelAsync(named: "05"))
            .append(ModelEntity.loadModelAsync(named: "06"))
            .append(ModelEntity.loadModelAsync(named: "07"))
            .append(ModelEntity.loadModelAsync(named: "08"))
            .collect()
            .sink(
                receiveCompletion: { error in
                    cancellable?.cancel()
                },
                receiveValue: { entities in
                    // creating displayable models from loaded models
                    var objects: [ModelEntity] = []
                    for entity in entities {
                        entity.setScale(SIMD3<Float>(0.002, 0.002, 0.002), relativeTo: anchor)
                        entity.generateCollisionShapes(recursive: true)
                        for _ in 1...2 {
                            objects.append(entity.clone(recursive: true))
                        }
                    }
                    
                    // shuffle them
                    objects.shuffle()
                    
                    // adding models on our cards
                    for (index, object) in objects.enumerated() {
                        cards[index].addChild(object)
                        cards[index].transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
                    }
                    
                    cancellable?.cancel()
                }
            )
    }
    
    private func flipCard(at location: CGPoint) {
        guard let card = arView.entity(at: location) else {
            return
        }
        
        var transform = card.transform
        
        if card.transform.rotation.angle == .pi {
            transform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        } else {
            transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        }
        
        card.move(to: transform, relativeTo: card.parent, duration: 0.25, timingFunction: .easeInOut)
    }
    
    @objc
    private func observeTaps(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        flipCard(at: tapLocation)
    }
}
