import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('stage3_prepare_audio',ROOT/'tooling/prepare_audio.py')
audio=importlib.util.module_from_spec(spec);sys.modules[spec.name]=audio;spec.loader.exec_module(audio)

class MediaProvenanceTest(unittest.TestCase):
    def test_reused_user_audio_is_not_claimed_as_new_elevenlabs_generation(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);source=root/'provided.wav'
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-f','lavfi','-i',
                'sine=frequency=500:sample_rate=44100:duration=0.3',str(source)],check=True)
            digest=hashlib.sha256(source.read_bytes()).hexdigest()
            clip={'key':'knock','kind':'reuse','sourcePath':'provided.wav','sha256':digest,
                  'provider':'User-provided Claude stage2','profile':'foley','category':'Foley','volume':.5}
            plan={'schemaVersion':1,'target':{'userId':'10735737143','universeId':'10776462844','placeId':'89520940302906'},
                  'voices':{},'clips':[clip]}
            path=root/'AUDIO_PLAN.json';path.write_text(json.dumps(plan))
            result=audio.build_atlases(path)
            self.assertEqual(result['clips']['knock']['provider'],'User-provided Claude stage2')
            self.assertEqual(result['segments']['knock']['fileKey'],'foley_atlas')
            self.assertIn('User-provided Claude stage2',result['production']['providers'])

    def test_supplied_seventeen_voices_and_knocks_have_hash_verified_sources(self):
        plan=audio.load_plan(ROOT/'audio/AUDIO_PLAN.json')
        reused=[c for c in plan['clips'] if c['kind']=='reuse' and c['category']=='Voice']
        self.assertEqual(len(reused),17)
        for clip in reused:
            self.assertEqual(hashlib.sha256((ROOT/'audio'/clip['sourcePath']).read_bytes()).hexdigest(),clip['sha256'])
        self.assertEqual(len([c for c in plan['clips'] if c['category']=='Voice']),20)

if __name__=='__main__':unittest.main()
