-- All balance and camera values live here. No paid assets required.
return table.freeze({
    WalkSpeed = 10,
    SprintSpeed = 18,
    MaxStamina = 100,
    DrainRate = 22,
    RegenRate = 16,
    RegenDelay = 1.5,
    RestartThreshold = 30,
    InteractionDistance = 14,
    ThreatSpeed = 8,
    ThreatChaseSpeed = 13,
    ThreatRange = 55,
    ThreatDamage = 24,
    ThreatHitCooldown = 1.4,
    Camera = table.freeze({BaseFov=74, SprintFov=80, BobStrength=0.045, MaxBlur=4}),
    Animations = table.freeze({Walk="", Run="", Idle=""}),
})
