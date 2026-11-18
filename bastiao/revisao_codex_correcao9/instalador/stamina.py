"""Single reviewed Sector7 exception: sprint drain 22 -> 19, all other bytes unchanged."""
import hashlib

PATH = ('ReplicatedStorage', 'Sector7', 'Config')
ORIGINAL = '-- All balance and camera values live here. No paid assets required.\nreturn table.freeze({\n    WalkSpeed = 10,\n    SprintSpeed = 18,\n    MaxStamina = 100,\n    DrainRate = 22,\n    RegenRate = 16,\n    RegenDelay = 1.5,\n    RestartThreshold = 30,\n    -- Bodycam: chest mount below the eyes (studs), lens angle measured\n    -- horizontally (degrees) so every screen shape sees the same width,\n    -- and the motion-blur cap for fast turns.\n    Camera = table.freeze({ChestDrop=0.72, ChestForward=0.28, WideHorizontalFov=112, NormalHorizontalFov=100, MaxTurnBlur=14}),\n    Animations = table.freeze({Walk="", Run="", Idle=""}),\n})\n'
SOURCE = ORIGINAL.replace('DrainRate = 22,', 'DrainRate = 19,')
ORIGINAL_SHA = hashlib.sha256(ORIGINAL.encode()).hexdigest()


def source_row():
    return {'path': list(PATH), 'cls': 'ModuleScript', 'source': SOURCE,
            'known': [ORIGINAL_SHA]}


def is_reviewed(row):
    return tuple(row.get('path', ())) == PATH and row.get('cls') == 'ModuleScript' and row.get('source') == SOURCE
