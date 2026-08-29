import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  async connect() {
    this.container = this.containerTarget || this.element
    this.isCleanedUp = false
    this.clock = null
    this.particles = []
    this.mouse = { x: 0, y: 0 }
    this.initialAngles = { azimuth: 0, polar: 0 }

    try {
      await this.loadDependencies()
      if (this.isCleanedUp) return
      this.initThreeExperience()
    } catch (err) {
      console.error("Failed to load Cline 3D experience dependencies:", err)
    }
  }

  disconnect() {
    this.isCleanedUp = true
    if (this.animId) {
      cancelAnimationFrame(this.animId)
    }
    if (this.onResize) {
      window.removeEventListener("resize", this.onResize)
    }
    if (this.onMouseMove) {
      window.removeEventListener("mousemove", this.onMouseMove)
    }
    if (this.controls) {
      this.controls.dispose()
    }
    if (this.renderer) {
      this.renderer.dispose()
    }
  }

  async loadDependencies() {
    const loadScript = (src) =>
      new Promise((resolve, reject) => {
        if (document.querySelector(`script[src="${src}"]`)) {
          resolve()
          return
        }
        const script = document.createElement("script")
        script.src = src
        script.onload = resolve
        script.onerror = reject
        document.head.appendChild(script)
      })

    if (!window.THREE) {
      await loadScript("https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js")
    }
    if (!window.THREE.ColladaLoader) {
      await loadScript("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/ColladaLoader.js")
    }
    if (!window.THREE.OrbitControls) {
      await loadScript("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js")
    }
    if (!window.THREE.AsciiEffect) {
      await loadScript("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/effects/AsciiEffect.js")
    }
  }

  initThreeExperience() {
    const THREE = window.THREE
    const container = this.container
    const width = container.clientWidth || 640
    const height = container.clientHeight || 520

    this.clock = new THREE.Clock()
    const scene = new THREE.Scene()
    this.scene = scene

    // Perspective Camera shifted slightly for optimal right-side placement
    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 1000)
    camera.position.set(0.01, -0.21, 1.18)
    this.camera = camera

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true })
    renderer.setSize(width, height)
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
    this.renderer = renderer

    let asciiEffect = null
    try {
      asciiEffect = new THREE.AsciiEffect(renderer, " .:-=+*#%@", {
        resolution: 0.22,
        scale: 1,
        color: false,
        alpha: true,
        block: false,
        invert: false
      })
      asciiEffect.setSize(width, height)
      asciiEffect.domElement.style.color = "#000000"
      asciiEffect.domElement.style.backgroundColor = "transparent"
      asciiEffect.domElement.style.width = "100%"
      asciiEffect.domElement.style.height = "100%"
      this.asciiEffect = asciiEffect
      container.appendChild(asciiEffect.domElement)
    } catch (e) {
      console.warn("AsciiEffect failed, using standard renderer", e)
      container.appendChild(renderer.domElement)
    }

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.5)
    scene.add(ambientLight)
    const dirLight = new THREE.DirectionalLight(0xffffff, 1.0)
    dirLight.position.set(10, 10, 5)
    scene.add(dirLight)
    const pointLight = new THREE.PointLight(0xffffff, 0.5)
    pointLight.position.set(-10, -10, -5)
    scene.add(pointLight)

    // Mascot Group - Shifted slightly to the right (X: +0.14)
    const group = new THREE.Group()
    group.rotation.set(-0.15, -0.3, 0)
    group.position.set(0.14, -0.5, 0)
    scene.add(group)
    this.group = group

    // Load Cline DAE Model
    const loader = new THREE.ColladaLoader()
    loader.load(
      "/3d/cline.dae",
      (collada) => {
        if (this.isCleanedUp) return
        const model = collada.scene
        model.scale.set(0.015, 0.015, 0.015)
        model.rotation.set(-Math.PI / 2, 0, 0)
        model.position.set(0, 0, 0)
        group.add(model)

        setTimeout(() => {
          if (this.controls && !this.controls._constraintsSet) {
            const az = this.controls.getAzimuthalAngle()
            const pol = this.controls.getPolarAngle()
            this.controls._trueLimits = {
              minAzimuth: az - 0.175,
              maxAzimuth: az + 0.175,
              minPolar: pol - 0.175,
              maxPolar: pol + 0.175
            }
            this.controls.minAzimuthAngle = az - 0.175 - 0.087
            this.controls.maxAzimuthAngle = az + 0.175 + 0.087
            this.controls.minPolarAngle = pol - 0.175 - 0.087
            this.controls.maxPolarAngle = pol + 0.175 + 0.087
            this.controls._constraintsSet = true
            this.initialAngles.azimuth = az
            this.initialAngles.polar = pol
          }
        }, 100)
      },
      undefined,
      (err) => {
        console.error("Error loading cline.dae:", err)
      }
    )

    // OrbitControls target centered on shifted group
    const eventElement = asciiEffect ? asciiEffect.domElement : renderer.domElement
    const controls = new THREE.OrbitControls(camera, eventElement)
    controls.enablePan = false
    controls.enableZoom = false
    controls.enableRotate = true
    controls.enableDamping = true
    controls.dampingFactor = 0.4
    controls.target.set(0.14, -0.25, 0)
    this.controls = controls

    // Particle Trails
    this.particles = ["<", "/", ">", "*", "&", "%", "$", "#"].map((char, index) => ({
      char,
      index,
      position: new THREE.Vector3(),
      particles: [],
      meshes: [],
      maxParticles: 119 + Math.floor(Math.random() * 42),
      agingRate: 0.003 + Math.random() * 0.002,
      trailColor: Math.random() > 0.5 ? "#6b7280" : "#374151"
    }))

    // Mouse Move Tracking
    this.onMouseMove = (e) => {
      this.mouse.x = (e.clientX / window.innerWidth) * 2 - 1
      this.mouse.y = -((e.clientY / window.innerHeight) * 2 - 1)
    }
    window.addEventListener("mousemove", this.onMouseMove)

    // Resize
    this.onResize = () => {
      if (!container || !camera || !renderer) return
      const w = container.clientWidth || 640
      const h = container.clientHeight || 520
      camera.aspect = w / h
      camera.updateProjectionMatrix()
      renderer.setSize(w, h)
      if (asciiEffect) asciiEffect.setSize(w, h)
    }
    window.addEventListener("resize", this.onResize)

    // Render Loop
    this.animate = () => {
      if (this.isCleanedUp) return
      this.animId = requestAnimationFrame(this.animate)

      const elapsedTime = this.clock.getElapsedTime()

      // 1. Orbiting Floating Particles
      const numP = this.particles.length
      this.particles.forEach((p) => {
        const angle = (p.index / numP) * Math.PI * 2 + elapsedTime * 0.3
        const x = Math.cos(angle) * 0.6
        const y = Math.sin(angle) * 0.6
        const z = Math.sin(elapsedTime * 0.15 + (p.index / numP) * Math.PI * 2) * 0.4
        p.position.set(x, z, y)

        if (elapsedTime % 0.04 < 0.016) {
          const pt = { pos: new THREE.Vector3(x, z, y), age: 0, size: 0.008 + Math.random() * 0.012 }
          p.particles.push(pt)
          const geom = new THREE.SphereGeometry(pt.size, 6, 6)
          const mat = new THREE.MeshStandardMaterial({ color: p.trailColor, transparent: true, opacity: 0.8 })
          const mesh = new THREE.Mesh(geom, mat)
          mesh.position.copy(pt.pos)
          if (this.group) this.group.add(mesh)
          p.meshes.push(mesh)

          if (p.particles.length > p.maxParticles) {
            p.particles.shift()
            const oldMesh = p.meshes.shift()
            if (oldMesh) {
              if (this.group) this.group.remove(oldMesh)
              oldMesh.geometry.dispose()
              oldMesh.material.dispose()
            }
          }
        }

        for (let i = p.particles.length - 1; i >= 0; i--) {
          const pt = p.particles[i]
          pt.age += p.agingRate
          if (pt.age >= 1) {
            const m = p.meshes[i]
            if (m) {
              if (this.group) this.group.remove(m)
              m.geometry.dispose()
              m.material.dispose()
            }
            p.particles.splice(i, 1)
            p.meshes.splice(i, 1)
          } else {
            const m = p.meshes[i]
            if (m) {
              const remaining = 1 - pt.age
              m.scale.setScalar(remaining)
              m.material.opacity = remaining * 0.8
            }
          }
        }
      })

      // 2. Mouse Tilting & Camera Constraints
      if (controls && controls._trueLimits) {
        const { minAzimuth, maxAzimuth, minPolar, maxPolar } = controls._trueLimits
        const spanAz = (maxAzimuth - minAzimuth) / 2
        const spanPol = (maxPolar - minPolar) / 2
        const targetAz = this.initialAngles.azimuth - this.mouse.x * spanAz * 0.5
        const targetPol = this.initialAngles.polar + this.mouse.y * spanPol * 0.5

        const clampedAz = Math.max(minAzimuth, Math.min(maxAzimuth, targetAz))
        const clampedPol = Math.max(minPolar, Math.min(maxPolar, targetPol))

        const spherical = new THREE.Spherical().setFromVector3(camera.position.clone().sub(controls.target))
        spherical.theta = THREE.MathUtils.lerp(spherical.theta, clampedAz, 0.05)
        spherical.phi = THREE.MathUtils.lerp(spherical.phi, clampedPol, 0.05)

        const newPos = new THREE.Vector3().setFromSpherical(spherical).add(controls.target)
        camera.position.copy(newPos)
      }

      controls.update()

      // 3. Render ASCII Scene
      if (asciiEffect) {
        asciiEffect.render(scene, camera)
      } else {
        renderer.render(scene, camera)
      }
    }

    this.animate()
  }
}
