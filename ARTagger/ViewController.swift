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

    private var requests = [VNRequest]()
    var screenCenter: CGPoint?
    var textNode: SCNNode?

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

        sceneView.session.delegate = self;

        // coreML vision
        setupVision()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        configuration.planeDetection = .horizontal
        
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

//    func updateText() {
//        guard let screenCenter = screenCenter else { return }
//
//        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: textNode?.position)
//        if let worldPos = worldPos {
//            textNode?.position = worldPos
//        }
//    }

//    func worldPositionFromScreenPosition(_ position: CGPoint,
//                                         objectPos: SCNVector3?,
//                                         infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
//
//        // -------------------------------------------------------------------------------
//        // 1. Always do a hit test against exisiting plane anchors first.
//        //    (If any such anchors exist & only within their extents.)
//
//        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
//        if let result = planeHitTestResults.first {
//
//            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
//            let planeAnchor = result.anchor
//
//            // Return immediately - this is the best possible outcome.
//            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
//        }
//
//        // -------------------------------------------------------------------------------
//        // 2. Collect more information about the environment by hit testing against
//        //    the feature point cloud, but do not return the result yet.
//
//        var featureHitTestPosition: SCNVector3?
//        var highQualityFeatureHitTestResult = false
//
//        let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
//
//        if !highQualityfeatureHitTestResults.isEmpty {
//            let result = highQualityfeatureHitTestResults[0]
//            featureHitTestPosition = result.position
//            highQualityFeatureHitTestResult = true
//        }
//
//        // -------------------------------------------------------------------------------
//        // 3. If desired or necessary (no good feature hit test result): Hit test
//        //    against an infinite, horizontal plane (ignoring the real world).
//
//        if (infinitePlane) || !highQualityFeatureHitTestResult {
//
//            let pointOnPlane = objectPos ?? SCNVector3Zero
//
//            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
//            if pointOnInfinitePlane != nil {
//                return (pointOnInfinitePlane, nil, true)
//            }
//        }
//
//        // -------------------------------------------------------------------------------
//        // 4. If available, return the result of the hit test against high quality
//        //    features if the hit tests against infinite planes were skipped or no
//        //    infinite plane was hit.
//
//        if highQualityFeatureHitTestResult {
//            return (featureHitTestPosition, nil, false)
//        }
//
//        // -------------------------------------------------------------------------------
//        // 5. As a last resort, perform a second, unfiltered hit test against features.
//        //    If there are no features in the scene, the result returned here will be nil.
//
//        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
//        if !unfilteredFeatureHitTestResults.isEmpty {
//            let result = unfilteredFeatureHitTestResults[0]
//            return (result.position, nil, false)
//        }
//
//        return (nil, nil, false)
//    }

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
                    let scnText = SCNText(string: firstPrediction.identifier, extrusionDepth: 1)
                    let textScale = 0.01 / Float(scnText.font.pointSize)
                    let textNode = SCNNode(geometry: scnText)
                    textNode.scale = SCNVector3Make(textScale, textScale, textScale)
                    textNode.position = self.sceneView.scene.rootNode.position
                    self.textNode = textNode
                    self.sceneView.scene.rootNode.addChildNode(textNode)
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

//    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        refreshFeaturePoints()
//
//        DispatchQueue.main.async {
//            self.updateFocusSquare()
//            self.hitTestVisualization?.render()
//
//            // If light estimation is enabled, update the intensity of the model's lights and the environment map
//            if let lightEstimate = self.session.currentFrame?.lightEstimate {
//                self.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
//            } else {
//                self.enableEnvironmentMapWithIntensity(25)
//            }
//        }
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
