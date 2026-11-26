"""Asset names shared between the city binder and the Termux media catalogue."""

MATERIALS = ("asphalt", "cement", "sidewalk", "glass", "steel", "brick", "roof", "tile")
METALLIC_MATERIALS = ("glass", "steel")
CHANNELS = ("color", "normal", "roughness")
PBR_ART = {
    f"mare_{material}_{channel}": (512, 512)
    for material in MATERIALS
    for channel in CHANNELS + (("metalness",) if material in METALLIC_MATERIALS else ())
}
MENU_ART = {"titulo_vetor": (1020, 258), "teloes_vetor": (1020, 1020), "fachadas_vetor": (1024, 1024)}
ARCHIVED_ART = frozenset({"title", "billboard", "facades", "vitrines"})
