import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'

function createEngine(){
	let scene = new THREE.Scene()
	scene.background = new THREE.Color(0x000000)

	// Create camera
	let camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000)
	camera.position.set(5, 5, 5)
	camera.lookAt(0, 0, 0)

	// Create renderer
	let renderer = new THREE.WebGLRenderer({ antialias: true })
	renderer.setSize(window.innerWidth, window.innerHeight)
	renderer.shadowMap.enabled = true
	document.body.appendChild(renderer.domElement)

	// Add orbit controls
	let controls = new OrbitControls(camera, renderer.domElement)
	controls.enableDamping = true
	controls.dampingFactor = 0.05

	// Add lights
	let ambientLight = new THREE.AmbientLight(0x404040, 3)
	scene.add(ambientLight)

	let directionalLight = new THREE.DirectionalLight(0xffffff, 3)
	directionalLight.position.set(5, 10, 7)
	directionalLight.castShadow = true
	directionalLight.shadow.mapSize.width = 1024
	directionalLight.shadow.mapSize.height = 1024
	scene.add(directionalLight)

	// Create a ground plane
	let planeGeometry = new THREE.PlaneGeometry(10, 10)
	let planeMaterial = new THREE.MeshStandardMaterial({ 
		color: 0x333333,
		side: THREE.DoubleSide
	})

	let plane = new THREE.Mesh(planeGeometry, planeMaterial)
	plane.rotation.x = -Math.PI / 2 // Rotate to be horizontal
	plane.position.y = 0
	plane.receiveShadow = true
	scene.add(plane)

	// Add grid helper
	let gridHelper = new THREE.GridHelper(10, 10)
	scene.add(gridHelper)

	// Handle window resize
	window.addEventListener('resize', () => {
		camera.aspect = window.innerWidth / window.innerHeight
		camera.updateProjectionMatrix()
		renderer.setSize(window.innerWidth, window.innerHeight)
	})

	function tick() {
		controls.update()
		renderer.render(scene, camera)
		requestAnimationFrame(tick)
	}

	return {
		scene,
		tick
	}
}

function createHelloCube(ctx){
	let cubeGeometry = new THREE.BoxGeometry(1, 1, 1)
	let cubeMaterial = new THREE.MeshStandardMaterial({ color: 0x1E90FF })
	let cube = new THREE.Mesh(cubeGeometry, cubeMaterial)
	cube.position.y = 0.5 // Position cube on top of the plane
	cube.castShadow = true
	ctx.scene.add(cube)
}

let ctx = createEngine()

createHelloCube(ctx)

ctx.tick()