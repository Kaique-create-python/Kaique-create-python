#!/usr/bin/env python3
"""Sign reviewed APK content with the phone's persistent development identity.

The private keystore stays in Termux private storage. It is never copied into the
repository, APK, phone Download folder or reports. This is a debug identity using
Android's conventional debug password, not a production signing setup.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

KEYSTORE=Path.home()/".local/share/veilbreakers-signing/development.p12"


def payload(apk):
    digest=hashlib.sha256()
    with zipfile.ZipFile(apk) as package:
        for name in sorted(package.namelist()):
            upper=name.upper()
            signing=upper.startswith("META-INF/") and (upper.endswith((".RSA",".DSA",".EC",".SF")) or upper=="META-INF/MANIFEST.MF")
            if signing or name.endswith("/"): continue
            digest.update(name.encode()); digest.update(b"\0"); digest.update(package.read(name))
    return digest.hexdigest()


def sign(source,destination):
    source=source.resolve(); destination=destination.resolve()
    if not source.is_file(): raise ValueError("Input APK is missing")
    if destination.exists(): raise ValueError("Output already exists; select a new reviewed release path")
    KEYSTORE.parent.mkdir(parents=True,exist_ok=True); KEYSTORE.parent.chmod(0o700)
    if not KEYSTORE.exists():
        subprocess.run(["keytool","-genkeypair","-storetype","PKCS12","-keystore",str(KEYSTORE),
                        "-alias","veilbreakers-development","-keyalg","RSA","-keysize","2048","-validity","10000",
                        "-dname","CN=VEILBREAKERS Development,O=VEILBREAKERS,C=BR",
                        "-storepass","android","-keypass","android"],check=True,capture_output=True)
    KEYSTORE.chmod(0o600)
    destination.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="veilbreakers-sign-") as temporary:
        aligned=Path(temporary)/"aligned.apk"
        subprocess.run(["zipalign","-f","4",str(source),str(aligned)],check=True,capture_output=True)
        subprocess.run(["apksigner","sign","--ks",str(KEYSTORE),"--ks-key-alias","veilbreakers-development",
                        "--ks-pass","pass:android","--key-pass","pass:android","--out",str(destination),str(aligned)],
                       check=True,capture_output=True)
    subprocess.run(["apksigner","verify",str(destination)],check=True,capture_output=True)
    subprocess.run(["zipalign","-c","4",str(destination)],check=True,capture_output=True)
    source_payload=payload(source); final_payload=payload(destination)
    if source_payload!=final_payload: raise ValueError("Signing altered reviewed game content; do not deliver output")
    return {"developmentSignatureVerified":True,"reviewedGameContentUnchanged":True,
            "reviewedInputSha256":hashlib.sha256(source.read_bytes()).hexdigest(),
            "deliveredApkSha256":hashlib.sha256(destination.read_bytes()).hexdigest(),
            "gamePayloadSha256":final_payload,"privateKeyExported":False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",required=True,type=Path); parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    print(json.dumps(sign(args.input,args.output)))


if __name__=="__main__": main()
