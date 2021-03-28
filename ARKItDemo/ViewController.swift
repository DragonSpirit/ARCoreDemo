//
//  ViewController.swift
//  ARKItDemo
//
//  Created by Nikolay Fedorov on 20.03.2021.
//

import UIKit
import SceneKit
import ARKit
import ARVideoKit
import Photos

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, RenderARDelegate, RecordARDelegate {
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var recoredBtn: UIButton!
    
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)
    
    var recorder: RecordAR?
    
    //Store The Rotation Of The CurrentNode
    var currentAngleY: Float = 0.0
    
    //Not Really Necessary But Can Use If You Like
    var isRotating = false
    
    var currentNode: SCNNode!
    
    var previewVisible = true
    
    let model = "sprint15m.usdz"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.debugOptions = [SCNDebugOptions.showWireframe, SCNDebugOptions.showFeaturePoints, SCNDebugOptions.showCreases]
        
        // Initialize ARVideoKit recorder
        
        recorder = RecordAR(ARSceneKit: sceneView)
        
        // Set the recorder's delegate
        recorder?.delegate = self
        
        // Set the renderer's delegate
        recorder?.renderAR = self
        
        // Configure the renderer to perform additional image & video processing 👁
        recorder?.onlyRenderWhileRecording = false
        
        // Configure ARKit content mode. Default is .auto
        recorder?.contentMode = .aspectFill
        
        //record or photo add environment light rendering, Default is false
        recorder?.enableAdjustEnvironmentLighting = true
        
        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
        
        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
    }
    
    @IBAction func click(_ sender: UIButton) {
        if recorder?.status == .readyToRecord {
            sender.setTitle("Stop", for: .normal)
            recordingQueue.async {
                self.recorder?.record()
            }
        } else if recorder?.status == .recording {
            sender.setTitle("Record", for: .normal)
            recorder?.stop() { path in
                self.recorder?.export(video: path) { saved, status in
                    DispatchQueue.main.sync {
                        self.exportMessage(success: saved, status: status)
                    }
                }
            }
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        recoredBtn.contentEdgeInsets = UIEdgeInsets(top: 20.0, left: 30.0, bottom: 20.0, right: 30.0)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        UIApplication.shared.isIdleTimerDisabled = true
        self.sceneView.autoenablesDefaultLighting = true
        sceneView.session.delegate = self
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        addGestures()
    }
    
    func addGestures () {
        let tapped = UITapGestureRecognizer(target: self, action: #selector(tapGesture))
        
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotateNode(_:)))
        
        sceneView.addGestureRecognizer(tapped)
        sceneView.addGestureRecognizer(rotateGesture)
    }
    
    @objc func tapGesture (sender: UITapGestureRecognizer) {
        let node = sceneView.scene.rootNode.childNode(withName: "CenterModel", recursively: false)
        let position = node?.position
        
        let newScene = SCNScene(named: model)!
        currentNode = newScene.rootNode.childNode(withName: "sprint15m", recursively: false)
        currentNode?.position = position!
        
        sceneView.scene.rootNode.addChildNode(currentNode!)
        
        sceneView.scene.rootNode.enumerateChildNodes { (child, _) in
            if child.name == "MeshNode" {
                child.removeFromParentNode()
            }
        }
        previewVisible = false
    }
    
    /// Rotates An SCNNode Around It's YAxis
    ///
    /// - Parameter gesture: UIRotationGestureRecognizer
    @objc func rotateNode(_ gesture: UIRotationGestureRecognizer){
        
        //1. Get The Current Rotation From The Gesture
        let rotation = Float(gesture.rotation)
        
        //2. If The Gesture State Has Changed Set The Nodes EulerAngles.y
        if gesture.state == .changed {
            isRotating = true
            currentNode.eulerAngles.y = currentAngleY + rotation
        }
        
        //3. If The Gesture Has Ended Store The Last Angle Of The Cube
        if(gesture.state == .ended) {
            currentAngleY = currentNode.eulerAngles.y
            isRotating = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        if recorder?.status == .recording {
            recorder?.stopAndExport()
        }
        recorder?.onlyRenderWhileRecording = true
        recorder?.prepare(ARWorldTrackingConfiguration())
        
        // Switch off the orientation lock for UIViewControllers with AR Scenes
        recorder?.rest()
    }
    
    // MARK: - Exported UIAlert present method
    func exportMessage(success: Bool, status:PHAuthorizationStatus) {
        if success {
            let alert = UIAlertController(title: "Exported", message: "Media exported to camera roll successfully!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Awesome", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else if status == .denied || status == .restricted || status == .notDetermined {
            let errorView = UIAlertController(title: "😅", message: "Please allow access to the photo library in order to save this media file.", preferredStyle: .alert)
            let settingsBtn = UIAlertAction(title: "Open Settings", style: .cancel) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(URL(string:UIApplication.openSettingsURLString)!)
                    }
                }
            }
            errorView.addAction(UIAlertAction(title: "Later", style: UIAlertAction.Style.default, handler: {
                (UIAlertAction)in
            }))
            errorView.addAction(settingsBtn)
            self.present(errorView, animated: true, completion: nil)
        }else{
            let alert = UIAlertController(title: "Exporting Failed", message: "There was an error while exporting your media file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let meshNode: SCNNode
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!) else {
            fatalError("Can't create plane geometry")
        }
        
        meshGeometry.update(from: planeAnchor.geometry)
        meshNode = SCNNode(geometry: meshGeometry)
        meshNode.opacity = 0.6
        meshNode.name = "MeshNode"
        
        guard let material = meshNode.geometry?.firstMaterial
        else { fatalError("ARSCNPlaneGeometry always has one material") }
        material.diffuse.contents = UIColor.blue
        
        node.addChildNode(meshNode)
        
        print("did add plane node")
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let planeNode = node.childNode(withName: "MeshNode", recursively: false)
        
        if let planeGeometry = planeNode?.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let location = sceneView.center
        guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal) else {
            return
        }
        let hitTest = sceneView.session.raycast(query)
        
        if hitTest.isEmpty {
            print("No Plane Detected")
            return
        } else {
            
            let columns = hitTest.first?.worldTransform.columns.3
            
            let position = SCNVector3(x: columns!.x, y: columns!.y, z: columns!.z)
            
            var node = sceneView.scene.rootNode.childNode(withName: "CenterModel", recursively: false) ?? nil
            if node == nil {
                let scene = SCNScene(named: model)!
                node = scene.rootNode.childNode(withName: "sprint15m", recursively: false)
                node?.opacity = 0.7
                let columns = hitTest.first?.worldTransform.columns.3
                node!.name = "CenterModel"
                node!.position = SCNVector3(x: columns!.x, y: columns!.y, z: columns!.z)
                sceneView.scene.rootNode.addChildNode(node!)
            }
            let position2 = node?.position
            
            if position == position2! {
                return
            } else {
                //action
                let action = SCNAction.move(to: position, duration: 0.1)
                node?.runAction(action)
            }
            node?.isHidden = !previewVisible
        }
    }
}


extension SCNNode {
    func centerAlign() {
        let (min, max) = boundingBox
        let extents = ((max) - (min))
        simdPivot = float4x4(translation: SIMD3((extents / 2) + (min)))
    }
}

extension float4x4 {
    init(translation vector: SIMD3<Float>) {
        self.init(SIMD4(1, 0, 0, 0),
                  SIMD4(0, 1, 0, 0),
                  SIMD4(0, 0, 1, 0),
                  SIMD4(vector.x, vector.y, vector.z, 1))
    }
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}
func / (left: SCNVector3, right: Int) -> SCNVector3 {
    return SCNVector3Make(left.x / Float(right), left.y / Float(right), left.z / Float(right))
}

extension Int {
    var degreesToradians : Double {return Double(self) * .pi/180}
}

func == (left: SCNVector3, right:SCNVector3) -> Bool {
    if (left.x == right.x && left.y == right.y && left.z == right.z) {
        return true
    } else {
        return false
    }
}

extension ViewController {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // Do some image/video processing.
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        if noError {
            // Do something with the video path.
        }
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        // Inform user an error occurred while recording.
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
        // Use this method to pause or stop video recording. Check [applicationWillResignActive(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive) for more information.
        if status == .recording {
            recorder?.stopAndExport()
        }
    }
}
