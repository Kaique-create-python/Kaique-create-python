"""Approved texture channels and native material settings for Maré Baixa."""

MATERIALS = {
    "asphalt": (1376, 16, {"color": "asphalt", "normal": "asphalt_normal", "roughness": "asphalt_rough"}),
    "cement": (816, 12, {"color": "concrete", "normal": "concrete_normal"}),
    "sidewalk": (836, 8, {"color": "concreto_rachado", "normal": "concreto_rachado_normal"}),
    "glass": (1568, 16, {}),
    "steel": (1088, 12, {"color": "metal_ondulado", "normal": "metal_ondulado_normal"}),
    "brick": (848, 10, {"color": "tijolo", "normal": "tijolo_normal"}),
    "roof": (800, 12, {}),
    "tile": (2306, 8, {"color": "piso_hexagonal", "normal": "piso_hexagonal_normal"}),
}
METALLIC_MATERIALS = ("glass", "steel")
CHANNELS = ("color", "normal", "roughness")
MAP_PROPERTIES = {
    "color": "ColorMapContent",
    "normal": "NormalMapContent",
    "roughness": "RoughnessMapContent",
    "metalness": "MetalnessMapContent",
}
VARIANT_PREFIX = "CyberOutlawMareBaixa_"
PBR_ART = {
    f"mare_{material}_{channel}": (512, 512)
    for material in MATERIALS
    for channel in CHANNELS + (("metalness",) if material in METALLIC_MATERIALS else ())
}
MENU_ART = {"titulo_vetor": (1020, 258), "teloes_vetor": (1020, 1020), "fachadas_vetor": (1024, 1024)}
ARCHIVED_ART = frozenset({"title", "billboard", "facades", "vitrines"})


def material_maps(art):
    maps = {}
    for key, (_, _, fallback) in MATERIALS.items():
        ids = {channel: art.get(f"mare_{key}_{channel}", 0) for channel in MAP_PROPERTIES}
        if not any(ids.values()):
            ids.update({channel: art.get(asset, 0) for channel, asset in fallback.items()})
        if any(ids.values()):
            maps[key] = ids
    return maps


def material_properties(art):
    variants = {}
    for key, ids in material_maps(art).items():
        base, studs, _ = MATERIALS[key]
        variants[VARIANT_PREFIX + key] = (
            ("BaseMaterial", "token", base),
            ("StudsPerTile", "float", studs),
            *((name, "Content", f"rbxassetid://{ids[channel]}" if ids[channel] else "")
              for channel, name in MAP_PROPERTIES.items()),
        )
    return variants
