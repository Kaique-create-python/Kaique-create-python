"""Build a portable .rbxlx and Studio Command Bar installer, using only Python stdlib.

The snapshot comes from tools/ExportSnapshot.luau in the verified Studio place.
Rebuild after a new snapshot: python tools/build_place.py
"""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"

def child(parent, tag, name, value):
    element = ET.SubElement(parent, tag, name=name)
    element.text = str(value)
    return element

def property_xml(parent, name, value):
    kind, v = value["t"], value.get("v")
    if kind == "boolean": child(parent, "bool", name, str(v).lower())
    elif kind == "number": child(parent, "double", name, v)
    elif kind == "EnumItem": child(parent, "token", name, v)
    elif kind == "Instance": child(parent, "Ref", name, v)
    elif kind == "string":
        if name == "Source": child(parent, "ProtectedString", name, v)
        elif name in {"Texture", "MeshId", "TextureId", "AnimationId"}:
            e = ET.SubElement(parent, "Content", name=name)
            ET.SubElement(e, "url").text = v
        else: child(parent, "string", name, v)
    elif kind in {"Vector3", "Vector2", "Color3"}:
        e = ET.SubElement(parent, kind, name=name)
        for k, n in zip("RGB" if kind == "Color3" else "XYZ", v):
            ET.SubElement(e, k).text = str(n)
    elif kind == "CFrame":
        e = ET.SubElement(parent, "CoordinateFrame", name=name)
        for k,n in zip(["X","Y","Z","R00","R01","R02","R10","R11","R12","R20","R21","R22"],v):
            ET.SubElement(e,k).text=str(n)
    elif kind in {"UDim2","UDim"}:
        e=ET.SubElement(parent,kind,name=name)
        for k,n in zip(["XS","XO","YS","YO"] if kind=="UDim2" else ["S","O"],v):
            ET.SubElement(e,k).text=str(n)

def item(parent, cls, name, referent):
    e=ET.SubElement(parent,"Item",{"class":cls,"referent":referent})
    props=ET.SubElement(e,"Properties")
    child(props,"string","Name",name)
    return e,props

def build_place():
    nodes=json.loads((BUILD/"studio-snapshot.json").read_text(encoding="utf-8-sig"))
    if isinstance(nodes,dict): nodes=list(nodes.values())
    # Scripts always come from current sources, while geometry and rig come from Studio.
    sources={}
    for p in (ROOT/"src").rglob("*.luau"):
        name=p.name.replace(".client","").replace(".server","").replace(".luau","")
        sources[name]=p.read_text(encoding="utf-8")
    for node in nodes:
        if node["name"] in sources and "Source" in node["properties"]:
            node["properties"]["Source"]={"t":"string","v":sources[node["name"]]}
    root=ET.Element("roblox",{"version":"4"})
    ET.SubElement(root,"External").text="null"
    ET.SubElement(root,"External").text="nil"
    services={}
    for name in ["Workspace","ReplicatedStorage","ServerScriptService"]:
        services[name]=item(root,name,name,"SERVICE_"+name)[0]
    lookup={}
    server=None
    for node in nodes:
        if node.get("parent"):
            parent=lookup[node["parent"]]
        elif node["class"]=="Model": parent=services["Workspace"]
        elif node["name"]=="Sector7":
            parent=services["ReplicatedStorage"] if any(c.get("parent")==node["id"] and c["name"]=="Config" for c in nodes) else services["ServerScriptService"]
        else: parent=root
        e,props=item(parent,node["class"],node["name"],node["id"])
        lookup[node["id"]]=e
        if parent is services["ServerScriptService"] and node["name"]=="Sector7": server=e
        for name,value in node["properties"].items():
            property_xml(props,name,value)
    assert server is not None
    manifest,_=item(server,"Folder","AttributeManifest","MANIFEST")
    count=0
    for node in nodes:
        attrs=node.get("attributes",{})
        if not attrs: continue
        e,p=item(manifest,"ObjectValue",f"Entry{count}",f"ATTR_{count}")
        child(p,"Ref","Value",node["id"])
        _,d=item(e,"StringValue","Data",f"DATA_{count}")
        child(d,"string","Value",json.dumps(attrs,ensure_ascii=False))
        count+=1
    ET.indent(root,space="  ")
    path=BUILD/"Sector7.rbxlx"
    ET.ElementTree(root).write(path,encoding="utf-8",xml_declaration=True)
    print(f"Built {path.name}: {len(nodes)} instances, {count} attribute entries, {path.stat().st_size} bytes")

def build_installer():
    files=[]
    for group,service in [("shared","ReplicatedStorage"),("server","ServerScriptService"),("client","StarterPlayer.StarterPlayerScripts")]:
        for p in sorted((ROOT/"src"/group).glob("*.luau")):
            cls="LocalScript" if ".client." in p.name else "Script" if ".server." in p.name else "ModuleScript"
            name=p.name.replace(".client","").replace(".server","").replace(".luau","")
            files.append((service,name,cls,p.read_text(encoding="utf-8")))
    lines=["-- Generated installer: run in Studio Command Bar while NOT playing.",
           "-- Replaces only Sector7-owned folders, map and StarterCharacter.",
           "assert(not game:GetService('RunService'):IsRunning(), 'Stop Play before installing')",
           "local RS=game:GetService('ReplicatedStorage');local SS=game:GetService('ServerScriptService');local SP=game:GetService('StarterPlayer')",
           "for _,p in {RS,SS} do local old=p:FindFirstChild('Sector7');if old then old:Destroy() end local f=Instance.new('Folder');f.Name='Sector7';f.Parent=p end",
           "local client=SP.StarterPlayerScripts:FindFirstChild('Sector7Client');if client then client:Destroy() end"]
    for service,name,cls,source in files:
        target="SP.StarterPlayerScripts" if service.startswith("StarterPlayer") else ("RS.Sector7" if service=="ReplicatedStorage" else "SS.Sector7")
        lines.append(f"do local s=Instance.new('{cls}');s.Name={json.dumps(name)};s.Source={json.dumps(source,ensure_ascii=False)};s.Parent={target} end")
    lines += [
        "local oldRig=SP:FindFirstChild('StarterCharacter');if oldRig then oldRig:Destroy() end",
        "local d=Instance.new('HumanoidDescription');d.HeadColor=Color3.fromRGB(183,170,145);d.TorsoColor=Color3.fromRGB(59,66,51);d.LeftArmColor=d.HeadColor;d.RightArmColor=d.HeadColor;d.LeftLegColor=Color3.fromRGB(39,42,35);d.RightLegColor=d.LeftLegColor",
        "local rig=game:GetService('Players'):CreateHumanoidModelFromDescriptionAsync(d,Enum.HumanoidRigType.R6);rig.Name='StarterCharacter';rig.PrimaryPart=rig.HumanoidRootPart;rig.Parent=SP",
        "game:GetService('StarterGui').ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor",
        "local world=require(SS.Sector7.WorldBuilder).Build();workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,5.5,15),Vector3.new(0,5,-40))",
        "print('[Sector7] Installed. Press Play.')"]
    (BUILD/"InstallSector7.luau").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("Built InstallSector7.luau")

if __name__=="__main__":
    BUILD.mkdir(exist_ok=True)
    build_installer()
    build_place()
