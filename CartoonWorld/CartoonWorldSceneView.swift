import SceneKit
import SwiftUI

struct CartoonWorldSceneView: UIViewRepresentable {
    let places: [WorldPlace]
    let contributions: [MediaContribution]
    let momentCountByPlace: [String: Int]
    @Binding var selectedPlaceID: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPlaceID: $selectedPlaceID)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.68, green: 0.90, blue: 0.98, alpha: 1)
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        let scene = context.coordinator.makeScene(
            places: places,
            contributions: contributions,
            momentCountByPlace: momentCountByPlace
        )
        view.scene = scene
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.sceneView = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.updateSelection(selectedPlaceID)
        context.coordinator.updateContributions(contributions)
        context.coordinator.updateMoments(momentCountByPlace)
    }

    final class Coordinator: NSObject {
        private var selectedPlaceID: Binding<String>
        private var placeNodes: [String: SCNNode] = [:]
        private var beaconNodes: [String: SCNNode] = [:]
        private var momentBeaconNodes: [String: SCNNode] = [:]
        private var avatarNode = SCNNode()
        private var cameraNode = SCNNode()
        weak var sceneView: SCNView?

        init(selectedPlaceID: Binding<String>) {
            self.selectedPlaceID = selectedPlaceID
        }

        func makeScene(places: [WorldPlace], contributions: [MediaContribution], momentCountByPlace: [String: Int]) -> SCNScene {
            let scene = SCNScene()
            scene.rootNode.addChildNode(makeCamera())
            scene.rootNode.addChildNode(makeSun())
            scene.rootNode.addChildNode(makeAmbientLight())
            scene.rootNode.addChildNode(makeOcean())
            scene.rootNode.addChildNode(makeGround())
            scene.rootNode.addChildNode(makeWater())
            scene.rootNode.addChildNode(makeMountainRange())
            scene.rootNode.addChildNode(makeHarbor())
            scene.rootNode.addChildNode(makeRoadNetwork())
            scene.rootNode.addChildNode(makeCloudRing())

            for place in places {
                let position = Self.worldPosition(for: place)
                let block = makePlaceBlock(place: place, position: position)
                scene.rootNode.addChildNode(block)
                placeNodes[place.id] = block

                let beacon = makeContributionBeacon(count: contributions.filter { $0.placeID == place.id }.count)
                beacon.position = SCNVector3(position.x + 1.0, 0.1, position.z - 1.0)
                scene.rootNode.addChildNode(beacon)
                beaconNodes[place.id] = beacon

                let momentBeacon = makeMomentBeacon(count: momentCountByPlace[place.id, default: 0])
                momentBeacon.position = SCNVector3(position.x - 1.12, 0.1, position.z + 1.02)
                scene.rootNode.addChildNode(momentBeacon)
                momentBeaconNodes[place.id] = momentBeacon
            }

            avatarNode = makeAvatar()
            scene.rootNode.addChildNode(avatarNode)
            animateAvatar()
            updateSelection(selectedPlaceID.wrappedValue)
            updateContributions(contributions)
            return scene
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = sceneView else { return }
            let point = recognizer.location(in: view)
            let hits = view.hitTest(point, options: [.boundingBoxOnly: false])
            guard let placeID = hits.lazy.compactMap({ self.nodePlaceID($0.node) }).first else { return }
            selectedPlaceID.wrappedValue = placeID
        }

        func updateSelection(_ placeID: String) {
            for (id, node) in placeNodes {
                let isSelected = id == placeID
                node.scale = isSelected ? SCNVector3(1.08, 1.08, 1.08) : SCNVector3(1, 1, 1)
                node.childNode(withName: "selectionRing", recursively: false)?.isHidden = !isSelected
                node.childNodes.forEach { child in
                    if let geometry = child.geometry {
                        geometry.materials.forEach { material in
                            material.emission.contents = isSelected ? UIColor.white.withAlphaComponent(0.16) : UIColor.black
                        }
                    }
                }
            }

            if let selected = placeNodes[placeID] {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.45
                avatarNode.position = SCNVector3(selected.position.x - 1.15, 0.52, selected.position.z + 1.1)
                avatarNode.eulerAngles.y += .pi * 0.12
                SCNTransaction.commit()
            }
        }

        func updateContributions(_ contributions: [MediaContribution]) {
            for (placeID, node) in beaconNodes {
                let count = contributions.filter { $0.placeID == placeID }.count
                node.isHidden = count == 0
                node.scale = SCNVector3(1, CGFloat(max(1, count)), 1)
                if count > 0 && node.action(forKey: "spin") == nil {
                    let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 5.5))
                    node.runAction(spin, forKey: "spin")
                }
            }
        }

        func updateMoments(_ momentCountByPlace: [String: Int]) {
            for (placeID, node) in momentBeaconNodes {
                let count = momentCountByPlace[placeID, default: 0]
                node.isHidden = count == 0
                node.scale = SCNVector3(1, CGFloat(max(1, count)), 1)
                if count > 0 {
                    if node.action(forKey: "float") == nil {
                        let up = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 1.2)
                        up.timingMode = .easeInEaseOut
                        let down = SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 1.2)
                        down.timingMode = .easeInEaseOut
                        node.runAction(.repeatForever(.sequence([up, down])), forKey: "float")
                    }
                } else {
                    node.removeAction(forKey: "float")
                }
            }
        }

        private func makeCamera() -> SCNNode {
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.orthographicScale = 15.4
            camera.fieldOfView = 38
            camera.zNear = 0.1
            camera.zFar = 100
            camera.wantsHDR = true

            cameraNode.camera = camera
            cameraNode.position = SCNVector3(8.4, 10.8, 9.6)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            return cameraNode
        }

        private func makeSun() -> SCNNode {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 1120
            light.castsShadow = true
            light.shadowRadius = 10
            light.shadowColor = UIColor.black.withAlphaComponent(0.20)

            let node = SCNNode()
            node.light = light
            node.eulerAngles = SCNVector3(-0.86, 0.58, -0.38)
            return node
        }

        private func makeAmbientLight() -> SCNNode {
            let light = SCNLight()
            light.type = .ambient
            light.intensity = 430
            light.color = UIColor(red: 0.82, green: 0.91, blue: 1, alpha: 1)

            let node = SCNNode()
            node.light = light
            return node
        }

        private func makeOcean() -> SCNNode {
            let plane = SCNPlane(width: 80, height: 80)
            plane.cornerRadius = 0
            plane.firstMaterial = material(UIColor(red: 0.33, green: 0.78, blue: 0.92, alpha: 1), roughness: 0.42)

            let node = SCNNode(geometry: plane)
            node.eulerAngles.x = -.pi / 2
            node.position = SCNVector3(0, -0.72, 0)
            return node
        }

        private func makeGround() -> SCNNode {
            let root = SCNNode()

            let island = SCNBox(width: 14.4, height: 1.02, length: 10.6, chamferRadius: 0.34)
            island.materials = [
                material(UIColor(red: 0.54, green: 0.78, blue: 0.36, alpha: 1), roughness: 0.76),
                material(UIColor(red: 0.42, green: 0.65, blue: 0.29, alpha: 1), roughness: 0.86),
                material(UIColor(red: 0.69, green: 0.58, blue: 0.39, alpha: 1), roughness: 0.9),
                material(UIColor(red: 0.69, green: 0.58, blue: 0.39, alpha: 1), roughness: 0.9),
                material(UIColor(red: 0.62, green: 0.52, blue: 0.35, alpha: 1), roughness: 0.9),
                material(UIColor(red: 0.62, green: 0.52, blue: 0.35, alpha: 1), roughness: 0.9)
            ]
            let islandNode = SCNNode(geometry: island)
            islandNode.position = SCNVector3(0, -0.44, 0)
            root.addChildNode(islandNode)

            let terraceMaterial = material(UIColor(red: 0.63, green: 0.86, blue: 0.42, alpha: 1), roughness: 0.72)
            let terraces: [(Float, Float, CGFloat, CGFloat, Float)] = [
                (-3.55, 2.45, 3.25, 2.0, 0.13),
                (2.8, 2.1, 3.85, 2.45, 0.11),
                (-4.05, -1.9, 2.7, 2.15, 0.10),
                (3.9, -1.62, 2.9, 2.25, 0.12)
            ]
            for terrace in terraces {
                let box = SCNBox(width: terrace.2, height: 0.18, length: terrace.3, chamferRadius: 0.18)
                box.firstMaterial = terraceMaterial
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(terrace.0, terrace.4, terrace.1)
                root.addChildNode(node)
            }

            return root
        }

        private func makeWater() -> SCNNode {
            let root = SCNNode()
            let riverMaterial = material(UIColor(red: 0.15, green: 0.72, blue: 0.93, alpha: 0.94), roughness: 0.28)
            let riverSegments: [(Float, Float, CGFloat, CGFloat, Float)] = [
                (-3.6, -2.75, 4.5, 0.95, 0.25),
                (0.7, -2.55, 5.4, 1.08, 0.10),
                (4.6, -2.85, 3.8, 0.98, -0.18)
            ]
            for segment in riverSegments {
                let river = SCNPlane(width: segment.2, height: segment.3)
                river.cornerRadius = 0.44
                river.firstMaterial = riverMaterial
                let node = SCNNode(geometry: river)
                node.eulerAngles = SCNVector3(-.pi / 2, 0, segment.4)
                node.position = SCNVector3(segment.0, 0.075, segment.1)
                root.addChildNode(node)
            }
            return root
        }

        private func makeMountainRange() -> SCNNode {
            let root = SCNNode()
            let peaks: [(Float, Float, CGFloat, CGFloat, UIColor)] = [
                (-5.6, 3.85, 1.32, 1.72, UIColor(red: 0.46, green: 0.70, blue: 0.47, alpha: 1)),
                (-4.7, 4.35, 0.95, 1.38, UIColor(red: 0.39, green: 0.62, blue: 0.43, alpha: 1)),
                (5.45, 3.75, 1.18, 1.58, UIColor(red: 0.49, green: 0.72, blue: 0.46, alpha: 1)),
                (6.15, 2.95, 0.82, 1.18, UIColor(red: 0.42, green: 0.65, blue: 0.42, alpha: 1))
            ]
            for peak in peaks {
                let cone = SCNCone(topRadius: 0, bottomRadius: peak.2, height: peak.3)
                cone.radialSegmentCount = 5
                cone.firstMaterial = material(peak.4, roughness: 0.82)
                let node = SCNNode(geometry: cone)
                node.position = SCNVector3(peak.0, Float(peak.3 / 2) + 0.04, peak.1)
                node.eulerAngles.y = peak.0 * 0.08
                root.addChildNode(node)

                let cap = SCNCone(topRadius: 0, bottomRadius: peak.2 * 0.34, height: peak.3 * 0.28)
                cap.radialSegmentCount = 5
                cap.firstMaterial = material(UIColor.white.withAlphaComponent(0.86), roughness: 0.48)
                let capNode = SCNNode(geometry: cap)
                capNode.position = SCNVector3(0, Float(peak.3 * 0.38), 0)
                node.addChildNode(capNode)
            }
            return root
        }

        private func makeHarbor() -> SCNNode {
            let root = SCNNode()
            let wood = material(UIColor(red: 0.66, green: 0.45, blue: 0.25, alpha: 1), roughness: 0.82)
            for x in [-4.9, -3.9, 4.3, 5.2] as [Float] {
                let pier = SCNBox(width: 0.24, height: 0.08, length: 1.1, chamferRadius: 0.03)
                pier.firstMaterial = wood
                let pierNode = SCNNode(geometry: pier)
                pierNode.position = SCNVector3(x, 0.15, -3.55)
                root.addChildNode(pierNode)
            }

            let boatColors = [
                UIColor(red: 1.0, green: 0.76, blue: 0.23, alpha: 1),
                UIColor(red: 0.98, green: 0.36, blue: 0.32, alpha: 1)
            ]
            for (index, x) in [-2.0, 2.25].enumerated() {
                let hull = SCNBox(width: 0.72, height: 0.18, length: 0.34, chamferRadius: 0.16)
                hull.firstMaterial = material(boatColors[index], roughness: 0.52)
                let hullNode = SCNNode(geometry: hull)
                hullNode.position = SCNVector3(Float(x), 0.18, -3.45)
                root.addChildNode(hullNode)

                let sail = SCNPyramid(width: 0.36, height: 0.56, length: 0.04)
                sail.firstMaterial = material(UIColor.white.withAlphaComponent(0.94), roughness: 0.38)
                let sailNode = SCNNode(geometry: sail)
                sailNode.position = SCNVector3(Float(x) + 0.08, 0.54, -3.45)
                sailNode.eulerAngles.y = .pi / 2
                root.addChildNode(sailNode)
            }

            return root
        }

        private func makeRoadNetwork() -> SCNNode {
            let root = SCNNode()
            let roadMaterial = material(UIColor(red: 0.93, green: 0.78, blue: 0.47, alpha: 1), roughness: 0.76)
            let roads: [(Float, Float, Float, Float)] = [
                (0, 0, 12.3, 0.46),
                (0, 2.75, 10.8, 0.34),
                (0, -2.25, 10.8, 0.34),
                (-4.0, 0, 8.4, 0.34),
                (0.0, 0, 8.2, 0.34),
                (4.0, 0, 8.4, 0.34)
            ]

            for (x, z, length, width) in roads {
                let road = SCNPlane(width: CGFloat(length), height: CGFloat(width))
                road.cornerRadius = CGFloat(width / 2)
                road.firstMaterial = roadMaterial
                let node = SCNNode(geometry: road)
                node.eulerAngles.x = -.pi / 2
                node.position = SCNVector3(x, 0.105, z)
                if abs(x) > 1.2 {
                    node.eulerAngles.z = .pi / 2
                }
                root.addChildNode(node)
            }
            addCrosswalks(to: root)
            return root
        }

        private func addCrosswalks(to root: SCNNode) {
            let stripeMaterial = material(UIColor.white.withAlphaComponent(0.92), roughness: 0.55)
            for x in [-4.0, 0.0, 4.0] as [Float] {
                for z in [-2.25, 0, 2.75] as [Float] {
                    for offset in [-0.18, 0, 0.18] as [Float] {
                        let stripe = SCNPlane(width: 0.5, height: 0.055)
                        stripe.firstMaterial = stripeMaterial
                        let node = SCNNode(geometry: stripe)
                        node.eulerAngles.x = -.pi / 2
                        node.position = SCNVector3(x + offset, 0.13, z)
                        root.addChildNode(node)
                    }
                }
            }
        }

        private func animateAvatar() {
            let up = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 0.85)
            up.timingMode = .easeInEaseOut
            let down = SCNAction.moveBy(x: 0, y: -0.1, z: 0, duration: 0.85)
            down.timingMode = .easeInEaseOut
            avatarNode.runAction(.repeatForever(.sequence([up, down])), forKey: "bob")
            avatarNode.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)), forKey: "turn")
        }

        private func makeCloudRing() -> SCNNode {
            let root = SCNNode()
            let cloudMaterial = material(UIColor.white.withAlphaComponent(0.90), roughness: 0.42)
            cloudMaterial.emission.contents = UIColor.white.withAlphaComponent(0.18)
            for index in 0..<10 {
                let cloud = SCNSphere(radius: CGFloat(0.13 + Double(index % 3) * 0.035))
                cloud.segmentCount = 16
                cloud.firstMaterial = cloudMaterial
                let node = SCNNode(geometry: cloud)
                let angle = Float(index) / 10.0 * .pi * 2
                node.position = SCNVector3(cos(angle) * 7.3, 3.2 + Float(index % 2) * 0.35, sin(angle) * 5.9)
                root.addChildNode(node)
            }
            return root
        }

        private func makePlaceBlock(place: WorldPlace, position: SCNVector3) -> SCNNode {
            let root = SCNNode()
            root.name = place.id
            root.position = position

            let base = SCNCylinder(radius: 1.03, height: 0.20)
            base.radialSegmentCount = 8
            base.firstMaterial = material(UIColor(red: 0.79, green: 0.91, blue: 0.57, alpha: 1), roughness: 0.70)
            let baseNode = SCNNode(geometry: base)
            baseNode.position.y = 0.1
            baseNode.eulerAngles.y = .pi / 8
            root.addChildNode(baseNode)

            let ring = SCNTorus(ringRadius: 1.11, pipeRadius: 0.03)
            ring.firstMaterial = material(UIColor(red: 0.17, green: 0.98, blue: 0.82, alpha: 0.9), roughness: 0.16)
            let ringNode = SCNNode(geometry: ring)
            ringNode.name = "selectionRing"
            ringNode.position.y = 0.18
            ringNode.eulerAngles.x = .pi / 2
            ringNode.isHidden = true
            ringNode.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 6)), forKey: "ringSpin")
            root.addChildNode(ringNode)

            switch place.id {
            case "luchiazui":
                addLujiazuiFantasySkyline(to: root)
            case "the-bund":
                addBundFantasyStreet(to: root)
            case "people-square":
                addTransitHub(to: root, color: roleColor(place.role))
            case "century-park":
                addTrees(to: root, color: roleColor(place.role))
                addPond(to: root)
            default:
                switch place.role {
                case .park:
                    addTrees(to: root, color: roleColor(place.role))
                case .transport:
                    addTransitHub(to: root, color: roleColor(place.role))
                case .lifestyle:
                    addLifestyleBlocks(to: root, color: roleColor(place.role))
                default:
                    addBuildingCluster(to: root, color: roleColor(place.role), seed: abs(place.id.hashValue), landmark: place.role == .landmark)
                }
            }
            return root
        }

        private func addBundFantasyStreet(to root: SCNNode) {
            let wallMaterial = material(UIColor(red: 0.94, green: 0.80, blue: 0.53, alpha: 1), roughness: 0.58)
            for index in 0..<5 {
                let x = Float(index) * 0.34 - 0.68
                let height = CGFloat(0.58 + Double(index % 2) * 0.13)
                let tower = SCNBox(width: 0.25, height: height, length: 0.33, chamferRadius: 0.035)
                tower.firstMaterial = wallMaterial
                let node = SCNNode(geometry: tower)
                node.position = SCNVector3(x, Float(height / 2) + 0.22, -0.16)
                root.addChildNode(node)

                let roof = SCNBox(width: 0.34, height: 0.08, length: 0.42, chamferRadius: 0.045)
                roof.firstMaterial = material(UIColor(red: 0.73, green: 0.28, blue: 0.18, alpha: 1), roughness: 0.5)
                let roofNode = SCNNode(geometry: roof)
                roofNode.position = SCNVector3(x, Float(height) + 0.29, -0.16)
                root.addChildNode(roofNode)
            }
            addStreetLanterns(to: root)
        }

        private func addLujiazuiFantasySkyline(to root: SCNNode) {
            let towerMaterial = material(UIColor(red: 0.34, green: 0.82, blue: 0.93, alpha: 1), roughness: 0.35)
            let core = SCNCylinder(radius: 0.12, height: 1.52)
            core.radialSegmentCount = 16
            core.firstMaterial = towerMaterial
            let coreNode = SCNNode(geometry: core)
            coreNode.position = SCNVector3(-0.24, 0.98, -0.06)
            root.addChildNode(coreNode)

            for pearl in [(0.55, 0.24, UIColor(red: 1.0, green: 0.42, blue: 0.56, alpha: 1)), (1.36, 0.18, UIColor(red: 1.0, green: 0.74, blue: 0.28, alpha: 1))] {
                let sphere = SCNSphere(radius: CGFloat(pearl.1))
                sphere.segmentCount = 24
                sphere.firstMaterial = material(pearl.2, roughness: 0.28)
                let pearlNode = SCNNode(geometry: sphere)
                pearlNode.position = SCNVector3(-0.24, Float(pearl.0), -0.06)
                root.addChildNode(pearlNode)
            }

            addBuildingCluster(to: root, color: UIColor(red: 0.54, green: 0.53, blue: 0.94, alpha: 1), seed: 7, landmark: true)
        }

        private func addPond(to root: SCNNode) {
            let pond = SCNCylinder(radius: 0.34, height: 0.035)
            pond.radialSegmentCount = 24
            pond.firstMaterial = material(UIColor(red: 0.17, green: 0.72, blue: 0.88, alpha: 0.9), roughness: 0.25)
            let node = SCNNode(geometry: pond)
            node.scale.x = 1.45
            node.position = SCNVector3(0.26, 0.23, -0.28)
            root.addChildNode(node)
        }

        private func addStreetLanterns(to root: SCNNode) {
            for x in [-0.82, 0.82] as [Float] {
                let pole = SCNCylinder(radius: 0.018, height: 0.44)
                pole.firstMaterial = material(UIColor(red: 0.30, green: 0.22, blue: 0.18, alpha: 1), roughness: 0.7)
                let poleNode = SCNNode(geometry: pole)
                poleNode.position = SCNVector3(x, 0.45, 0.46)
                root.addChildNode(poleNode)

                let lamp = SCNSphere(radius: 0.06)
                lamp.segmentCount = 14
                let lampMaterial = material(UIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1), roughness: 0.25)
                lampMaterial.emission.contents = UIColor(red: 1.0, green: 0.58, blue: 0.12, alpha: 0.35)
                lamp.firstMaterial = lampMaterial
                let lampNode = SCNNode(geometry: lamp)
                lampNode.position = SCNVector3(x, 0.70, 0.46)
                root.addChildNode(lampNode)
            }
        }

        private func addBuildingCluster(to root: SCNNode, color: UIColor, seed: Int, landmark: Bool = false) {
            let positions: [(Float, Float)] = [(-0.42, -0.34), (0.16, -0.20), (0.50, 0.34), (-0.24, 0.44)]
            for (index, pair) in positions.enumerated() {
                let baseHeight = landmark ? 0.78 : 0.38
                let height = CGFloat(baseHeight + Double((seed + index) % 4) * 0.14)
                let box = SCNBox(width: 0.34, height: height, length: 0.34, chamferRadius: 0.04)
                box.firstMaterial = material(color, roughness: 0.48)
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(pair.0, Float(height / 2) + 0.24, pair.1)
                root.addChildNode(node)

                let eave = SCNBox(width: 0.48, height: 0.055, length: 0.48, chamferRadius: 0.035)
                eave.firstMaterial = material(roofColor(index), roughness: 0.48)
                let eaveNode = SCNNode(geometry: eave)
                eaveNode.position = SCNVector3(pair.0, Float(height) + 0.29, pair.1)
                root.addChildNode(eaveNode)

                let cap = SCNPyramid(width: 0.42, height: 0.16, length: 0.42)
                cap.firstMaterial = material(roofColor(index + 1), roughness: 0.45)
                let capNode = SCNNode(geometry: cap)
                capNode.position = SCNVector3(pair.0, Float(height) + 0.39, pair.1)
                root.addChildNode(capNode)

                addWindows(to: node, height: height)
            }
        }

        private func addWindows(to building: SCNNode, height: CGFloat) {
            let rows = max(2, Int(height / 0.18))
            for row in 0..<rows {
                for column in [-0.11, 0.11] {
                    let window = SCNPlane(width: 0.058, height: 0.038)
                    window.cornerRadius = 0.018
                    let windowMaterial = material(UIColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 0.82), roughness: 0.22)
                    windowMaterial.emission.contents = UIColor(red: 1.0, green: 0.64, blue: 0.16, alpha: 0.18)
                    window.firstMaterial = windowMaterial
                    let node = SCNNode(geometry: window)
                    node.position = SCNVector3(Float(column), Float(row) * 0.16 - Float(height / 2) + 0.13, 0.173)
                    building.addChildNode(node)
                }
            }
        }

        private func addTrees(to root: SCNNode, color: UIColor) {
            for index in 0..<10 {
                let angle = Float(index) / 10.0 * .pi * 2
                let radius: Float = index % 3 == 0 ? 0.32 : 0.64
                let trunk = SCNCylinder(radius: 0.035, height: 0.30)
                trunk.firstMaterial = material(UIColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1), roughness: 0.8)
                let trunkNode = SCNNode(geometry: trunk)
                trunkNode.position = SCNVector3(cos(angle) * radius, 0.38, sin(angle) * radius)
                root.addChildNode(trunkNode)

                let crown = SCNCone(topRadius: 0.04, bottomRadius: 0.20, height: 0.34)
                crown.radialSegmentCount = 7
                crown.firstMaterial = material(color, roughness: 0.62)
                let crownNode = SCNNode(geometry: crown)
                crownNode.position = SCNVector3(trunkNode.position.x, 0.68, trunkNode.position.z)
                root.addChildNode(crownNode)
            }
        }

        private func addTransitHub(to root: SCNNode, color: UIColor) {
            let base = SCNCylinder(radius: 0.52, height: 0.16)
            base.radialSegmentCount = 18
            base.firstMaterial = material(UIColor(red: 0.95, green: 0.89, blue: 0.72, alpha: 1), roughness: 0.6)
            let baseNode = SCNNode(geometry: base)
            baseNode.position.y = 0.30
            root.addChildNode(baseNode)

            let torus = SCNTorus(ringRadius: 0.42, pipeRadius: 0.05)
            torus.firstMaterial = material(color, roughness: 0.35)
            let torusNode = SCNNode(geometry: torus)
            torusNode.position.y = 0.58
            torusNode.eulerAngles.x = .pi / 2
            root.addChildNode(torusNode)

            let train = SCNBox(width: 0.96, height: 0.20, length: 0.25, chamferRadius: 0.09)
            train.firstMaterial = material(UIColor.white, roughness: 0.32)
            let trainNode = SCNNode(geometry: train)
            trainNode.position = SCNVector3(0, 0.52, 0)
            root.addChildNode(trainNode)
        }

        private func addLifestyleBlocks(to root: SCNNode, color: UIColor) {
            addBuildingCluster(to: root, color: color, seed: 12)
            let dome = SCNSphere(radius: 0.33)
            dome.segmentCount = 24
            dome.firstMaterial = material(UIColor(red: 1, green: 0.78, blue: 0.25, alpha: 1), roughness: 0.35)
            let node = SCNNode(geometry: dome)
            node.scale.y = 0.42
            node.position = SCNVector3(0.68, 0.56, -0.66)
            root.addChildNode(node)
        }

        private func makeContributionBeacon(count: Int) -> SCNNode {
            let root = SCNNode()
            root.isHidden = count == 0

            let beam = SCNCylinder(radius: 0.05, height: 0.95)
            let beamMaterial = material(UIColor(red: 0.22, green: 0.98, blue: 0.78, alpha: 0.48), roughness: 0.16)
            beamMaterial.emission.contents = UIColor(red: 0.12, green: 0.72, blue: 0.50, alpha: 0.22)
            beam.firstMaterial = beamMaterial
            let beamNode = SCNNode(geometry: beam)
            beamNode.position.y = 0.64
            root.addChildNode(beamNode)

            let crystal = SCNPyramid(width: 0.34, height: 0.42, length: 0.34)
            let crystalMaterial = material(UIColor(red: 0.14, green: 0.96, blue: 0.78, alpha: 0.9), roughness: 0.12)
            crystalMaterial.emission.contents = UIColor(red: 0.08, green: 0.72, blue: 0.52, alpha: 0.20)
            crystal.firstMaterial = crystalMaterial
            let crystalNode = SCNNode(geometry: crystal)
            crystalNode.position.y = 1.17
            root.addChildNode(crystalNode)
            return root
        }

        private func makeMomentBeacon(count: Int) -> SCNNode {
            let root = SCNNode()
            root.isHidden = count == 0

            let shell = SCNTorus(ringRadius: 0.34, pipeRadius: 0.028)
            let shellMaterial = material(UIColor(red: 0.88, green: 0.25, blue: 0.98, alpha: 0.75), roughness: 0.14)
            shellMaterial.emission.contents = UIColor(red: 0.67, green: 0.2, blue: 0.95, alpha: 0.2)
            shell.firstMaterial = shellMaterial
            let shellNode = SCNNode(geometry: shell)
            shellNode.position = SCNVector3(0, 1.0, 0)
            shellNode.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: .pi / 10, duration: 4.5)), forKey: "momentSpin")
            root.addChildNode(shellNode)

            let core = SCNCapsule(capRadius: 0.03, height: 0.12)
            let coreMaterial = material(UIColor(red: 1, green: 0.85, blue: 1, alpha: 0.9), roughness: 0.08)
            coreMaterial.emission.contents = UIColor(red: 0.85, green: 0.52, blue: 1, alpha: 0.28)
            core.firstMaterial = coreMaterial
            let coreNode = SCNNode(geometry: core)
            coreNode.position = SCNVector3(0, 1.22, 0)
            root.addChildNode(coreNode)

            return root
        }

        private func makeAvatar() -> SCNNode {
            let root = SCNNode()

            let body = SCNSphere(radius: 0.24)
            body.segmentCount = 24
            body.firstMaterial = material(UIColor(red: 0.10, green: 0.78, blue: 0.72, alpha: 1), roughness: 0.42)
            let bodyNode = SCNNode(geometry: body)
            root.addChildNode(bodyNode)

            let face = SCNPlane(width: 0.30, height: 0.18)
            face.cornerRadius = 0.08
            face.firstMaterial = material(UIColor.white, roughness: 0.25)
            let faceNode = SCNNode(geometry: face)
            faceNode.position = SCNVector3(0, 0.02, 0.225)
            root.addChildNode(faceNode)

            for x in [-0.08, 0.08] {
                let eye = SCNSphere(radius: 0.018)
                eye.firstMaterial = material(UIColor.black, roughness: 0.3)
                let eyeNode = SCNNode(geometry: eye)
                eyeNode.position = SCNVector3(Float(x), 0.04, 0.235)
                root.addChildNode(eyeNode)
            }
            return root
        }

        private func nodePlaceID(_ node: SCNNode?) -> String? {
            var cursor = node
            while let current = cursor {
                if let name = current.name, placeNodes[name] != nil {
                    return name
                }
                cursor = current.parent
            }
            return nil
        }

        private func material(_ color: UIColor, roughness: CGFloat) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.roughness.contents = roughness
            material.lightingModel = .physicallyBased
            return material
        }

        private func roleColor(_ role: PlaceRole) -> UIColor {
            switch role {
            case .landmark:
                UIColor(red: 1.00, green: 0.55, blue: 0.16, alpha: 1)
            case .neighborhood:
                UIColor(red: 0.08, green: 0.74, blue: 0.88, alpha: 1)
            case .park:
                UIColor(red: 0.20, green: 0.78, blue: 0.30, alpha: 1)
            case .transport:
                UIColor(red: 0.35, green: 0.30, blue: 0.96, alpha: 1)
            case .lifestyle:
                UIColor(red: 1.00, green: 0.18, blue: 0.40, alpha: 1)
            }
        }

        private func roofColor(_ index: Int) -> UIColor {
            let colors = [
                UIColor(red: 0.98, green: 0.36, blue: 0.23, alpha: 1),
                UIColor(red: 0.20, green: 0.72, blue: 0.92, alpha: 1),
                UIColor(red: 0.98, green: 0.76, blue: 0.22, alpha: 1),
                UIColor(red: 0.55, green: 0.40, blue: 0.95, alpha: 1)
            ]
            return colors[index % colors.count]
        }

        private static func worldPosition(for place: WorldPlace) -> SCNVector3 {
            let centerLatitude = 31.2244
            let centerLongitude = 121.4737
            let latMeters = (place.latitude - centerLatitude) * 111_000
            let lonMeters = (place.longitude - centerLongitude) * 111_000 * cos(centerLatitude * .pi / 180)
            let scale = 0.00028
            return SCNVector3(Float(lonMeters * scale), 0, Float(-latMeters * scale))
        }
    }
}
