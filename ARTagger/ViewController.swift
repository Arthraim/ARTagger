//
//  ViewController.swift
//  ARTagger
//
//  Created by Arthur Wang on 7/7/17.
//  Copyright © 2017 YANGAPP. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreML
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

//    var session: ARSession!

    var text: String?

    private var requests = [VNRequest]()
    var screenCenter: CGPoint?

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.preferredFramesPerSecond = 60

        DispatchQueue.main.async {
            self.screenCenter = self.sceneView.bounds.mid
        }

        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/empty.scn")!

        // Set the scene to the view
        sceneView.scene = scene

        sceneView.session.delegate = self

        // coreML vision
        setupVision()

        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTag(gestureRecognizer:))))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
//        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

//    func addText(text: String) {
    @objc
    func handleTag(gestureRecognizer: UITapGestureRecognizer) {
        guard let currentFrame = sceneView.session.currentFrame else { return }

        let scnText = SCNText(string: String(text ?? "ERROR"), extrusionDepth: 1)
        scnText.firstMaterial?.lightingModel = .constant

        let textScale = 0.02 / Float(scnText.font.pointSize)
        let textNode = SCNNode(geometry: scnText)
        textNode.scale = SCNVector3Make(textScale, textScale, textScale)
        sceneView.scene.rootNode.addChildNode(textNode)

        // Set transform of node to be 10cm in front of camera
        var translation = textNode.simdTransform
        translation.columns.3.z = -0.2
        textNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)

        addHomeTags(currentFrame: currentFrame)
    }

    func addHomeTags(currentFrame: ARFrame) {
        if (text == "mouse") {
            addHomeTag(imageName: "razer", currentFrame: currentFrame)
        } else if (text == "iPod") {
            addHomeTag(imageName: "nokia", currentFrame: currentFrame)
        }
    }

    func addHomeTag(imageName: String, currentFrame: ARFrame) {
        let image = UIImage(named: imageName)
        // Create an image plane using a snapshot of the view
        let imagePlain = SCNPlane(width: sceneView.bounds.width / 6000,
                                  height: sceneView.bounds.height / 6000)
        imagePlain.firstMaterial?.diffuse.contents = image
        imagePlain.firstMaterial?.lightingModel = .constant

        let plainNode = SCNNode(geometry: imagePlain)
        sceneView.scene.rootNode.addChildNode(plainNode)

        // Set transform of node to be 10cm in front of camera
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.22
        translation.columns.3.y = 0.05
        plainNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
    }

    // MARK: - coreML vision logic
    func setupVision() {
        //guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model)
        guard let visionModel = try? VNCoreMLModel(for: Resnet50().model)
            else { fatalError("Can't load VisionML model") }
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop
        self.requests = [classificationRequest]
    }

    func handleClassifications(request: VNRequest, error: Error?) {
        guard let observations = request.results
            else { print("no results: \(error!)"); return }
        let classifications = observations[0...4]
            .flatMap({ $0 as? VNClassificationObservation })
            //            .filter({ $0.confidence > 0.3 })
            .sorted(by: { $0.confidence > $1.confidence })

        DispatchQueue.main.async {
            let text = classifications.map {
                (prediction: VNClassificationObservation) -> String in
                return "\(round(prediction.confidence * 100 * 100)/100)%: \(prediction.identifier)"
            }
            print(text.joined(separator: " | "))

            // add 3d text
            if let firstPrediction = classifications.first {
                if firstPrediction.confidence > 0.1 {
//                    self.addText(text: firstPrediction.identifier)
                    if let t = firstPrediction.identifier.split(separator: ",").first {
                        self.text = String(t)
                    }
                }
            }

        }
    }

    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
//    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
//        if let textNote = textNode {
//            updateText()
//            return textNode
//        }
//        let node = SCNNode()
//        return node
//    }

//    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//        // This visualization covers only detected planes.
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//
//        // Create a SceneKit plane to visualize the node using its position and extent.
//        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
//        let planeNode = SCNNode(geometry: plane)
//        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
//
//        // SCNPlanes are vertically oriented in their local coordinate space.
//        // Rotate it to match the horizontal orientation of the ARPlaneAnchor.
//        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
//
//        // ARKit owns the node corresponding to the anchor, so make the plane a child node.
//        node.addChildNode(planeNode)
//    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }

    var i = 0
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        i = i + 1
        if (i % 10 == 0) {
//        if (i <= 10) {
            DispatchQueue.global(qos: .background).async {
                var requestOptions:[VNImageOption : Any] = [:]
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, orientation: 1, options: requestOptions)
                do {
                    try imageRequestHandler.perform(self.requests)
                } catch {
                    print(error)
                }
            }
        }
    }
}
