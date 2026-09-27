import SceneKit
import UIKit

/// Builds the rain/snow SCNParticleSystems used above the house — mirrors app.js's
/// weatherParticles array (drift, fall speed, size all tuned to feel the same), just driven by
/// SceneKit's particle engine instead of hand-rolled canvas points.
enum WeatherParticles {
    static func makeRain() -> SCNParticleSystem {
        let system = SCNParticleSystem()
        system.loops = true
        system.birthRate = 500
        system.particleLifeSpan = 1.3
        system.particleLifeSpanVariation = 0.3
        system.emitterShape = SCNBox(width: 16, height: 0.01, length: 9, chamferRadius: 0)
        system.birthLocation = .volume
        system.emittingDirection = SCNVector3(0, -1, 0)
        system.spreadingAngle = 4
        system.particleVelocity = 9
        system.particleVelocityVariation = 1.5
        system.isAffectedByGravity = false
        system.particleColor = UIColor(red: 0.7, green: 0.78, blue: 0.9, alpha: 0.55)
        system.particleSize = 0.02
        system.particleSizeVariation = 0.01
        system.stretchFactor = 0.06
        system.blendMode = .alpha
        return system
    }

    static func makeSnow() -> SCNParticleSystem {
        let system = SCNParticleSystem()
        system.loops = true
        system.birthRate = 60
        system.particleLifeSpan = 6
        system.particleLifeSpanVariation = 1.5
        system.emitterShape = SCNBox(width: 16, height: 0.01, length: 9, chamferRadius: 0)
        system.birthLocation = .volume
        system.emittingDirection = SCNVector3(0, -1, 0)
        system.spreadingAngle = 25
        system.particleVelocity = 1.1
        system.particleVelocityVariation = 0.4
        system.isAffectedByGravity = false
        system.particleColor = UIColor(white: 1, alpha: 0.9)
        system.particleSize = 0.045
        system.particleSizeVariation = 0.02
        system.blendMode = .alpha
        return system
    }
}
