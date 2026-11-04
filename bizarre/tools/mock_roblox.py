#!/usr/bin/env python3
"""Open Cloud falsa (só para testar o instalador do BIZARRE sem tocar no Roblox).
uso: python3 bizarre/tools/mock_roblox.py PORTA [--falhar] [--sem-audio] [--revisao AJUSTE-2]
  --falhar     o teste da nuvem devolve erro (o instalador NÃO pode publicar)
  --sem-audio  a chave não tem permissão de enviar áudio (o instalador tem que seguir sem as vozes)
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

ARGS = sys.argv[1:]
REVISAO = ARGS[ARGS.index("--revisao") + 1] if "--revisao" in ARGS else "AJUSTE-2"
ESTADO = {"versao": 40, "tarefas": {}, "places": [], "falhar": "--falhar" in ARGS, "sem_audio": "--sem-audio" in ARGS,
          "ultimo_place": b"", "audios": 0}
UNIVERSE = "10774214555"
ID_AUDIO = "777000111"
MARCADOR = b"BBVOZ" + b"_" * 59


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def responder(self, codigo, obj):
        corpo = json.dumps(obj).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def corpo(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n)

    def do_GET(self):
        if self.path.startswith("/v1/games"):
            return self.responder(200, {"data": [{"name": "BIZARRE BATTLEGROUNDS", "creator": {"id": 1357078972, "name": "dono", "type": "User"}}]})
        if self.headers.get("x-api-key") != "CHAVE-DE-TESTE":
            return self.responder(401, {"message": "chave errada"})
        if self.path.startswith("/assets/v1/operations/"):
            return self.responder(200, {"done": True, "response": {"assetId": ID_AUDIO, "moderationResult": {"moderationState": "Approved"}}})
        if self.path.startswith("/assets/v1/assets/"):
            return self.responder(200, {"moderationResult": {"moderationState": "Approved"}})
        if self.path.endswith("/logs?maxPageSize=200"):
            return self.responder(200, {"luauExecutionSessionTaskLogs": [{"messages": ["log de teste"]}]})
        m = re.match(r"/cloud/v2/(universes/.+/tasks/(\w+))$", self.path)
        if m:
            t = ESTADO["tarefas"][m.group(2)]
            t["consultas"] += 1
            if t["consultas"] < 2:
                return self.responder(200, {"path": m.group(1), "state": "PROCESSING"})
            if "C.REVISAO" in t["script"]:
                res = json.dumps({"revisao": REVISAO})
            elif ESTADO["falhar"]:
                res = json.dumps({"ok": False, "erros": ["golpe KILLER_QUEEN_ULT deu erro: simulado"], "avisos": [], "info": {}})
            else:
                tem_voz = MARCADOR not in ESTADO["ultimo_place"]
                res = json.dumps({"ok": True, "erros": [], "avisos": ["SILVER_CHARIOT_4 não acertou o boneco de teste"], "info": {
                    "modulos": 36, "revisao": REVISAO, "quebraveis": 148170, "spawns": 14, "streaming": True,
                    "quebraTeste": "40 peças quebraram e 40 voltaram",
                    "vozes": ("áudio " + ID_AUDIO) if tem_voz else "sem áudio (usa o grito da biblioteca)",
                    "stands": {"STAR_PLATINUM": "catálogo R6: roupa 2, acessórios 6/6, juntas 6",
                               "THE_WORLD": "catálogo R6: roupa 2, acessórios 5/5, juntas 6",
                               "MAGICIANS_RED": "catálogo R6: roupa 1, acessórios 2/2, juntas 6",
                               "SILVER_CHARIOT": "catálogo R6: roupa 2, acessórios 3/3, juntas 6",
                               "CRAZY_DIAMOND": "reserva, juntas 6",
                               "KILLER_QUEEN": "catálogo R6: roupa 2, acessórios 4/4, juntas 6"},
                    "m1": "14.0 de dano, ragdoll true", "golpes": {"STAR_PLATINUM_1": "31.2", "THE_WORLD_ULT": "48.0", "KILLER_QUEEN_1": "15.0"},
                    "sons": "55/56"}})
            return self.responder(200, {"path": m.group(1), "state": "COMPLETE", "output": {"results": [res]}})
        self.responder(404, {"message": "nao achei " + self.path})

    def do_PATCH(self):
        if self.headers.get("x-api-key") != "CHAVE-DE-TESTE":
            return self.responder(401, {"message": "chave errada"})
        corpo = json.loads(self.corpo() or b"{}")
        if self.path == "/asset-permissions-api/v1/assets/permissions":
            assert corpo["subjectType"] == "Universe" and corpo["subjectId"] == UNIVERSE, corpo
            ids = [r["assetId"] for r in corpo["requests"]]
            print("MOCK liberar", ids, flush=True)
            return self.responder(200, {"successAssetIds": ids})
        self.responder(404, {"message": "nao achei " + self.path})

    def do_POST(self):
        if self.headers.get("x-api-key") != "CHAVE-DE-TESTE":
            return self.responder(401, {"message": "chave errada"})
        corpo = self.corpo()
        if self.path == "/assets/v1/assets":
            if ESTADO["sem_audio"]:
                return self.responder(403, {"message": "Insufficient scope: asset:write"})
            assert self.headers.get("Content-Type", "").startswith("multipart/form-data; boundary="), self.headers
            assert b'"assetType": "Audio"' in corpo and b"OggS" in corpo, "áudio estranho"
            ESTADO["audios"] += 1
            print("MOCK audio", len(corpo), "bytes", flush=True)
            return self.responder(200, {"path": "operations/op1", "operationId": "op1", "done": False})
        m = re.match(r"/universes/v1/(\d+)/places/(\d+)/versions\?versionType=(\w+)", self.path)
        if m:
            assert self.headers.get("Content-Type") == "application/octet-stream", self.headers.get("Content-Type")
            assert m.group(1) == UNIVERSE and m.group(2) == "108061345551908", self.path
            assert corpo[:8] == b"<roblox!", "place não é binário"
            if not ESTADO["sem_audio"]:
                assert MARCADOR not in corpo and (ID_AUDIO.encode() + b" ") in corpo, "o número das vozes não entrou no place"
            ESTADO["ultimo_place"] = corpo
            ESTADO["versao"] += 1
            ESTADO["places"].append(m.group(3))
            print("MOCK place", m.group(3), "versao", ESTADO["versao"], len(corpo), "bytes", flush=True)
            return self.responder(200, {"versionNumber": ESTADO["versao"]})
        m = re.match(r"/cloud/v2/universes/(\d+)/places/(\d+)/versions/(\d+)/luau-execution-session-tasks", self.path)
        if m:
            d = json.loads(corpo)
            tid = "t%d" % (len(ESTADO["tarefas"]) + 1)
            ESTADO["tarefas"][tid] = {"consultas": 0, "script": d["script"]}
            print("MOCK luau versao", m.group(3), "script", len(d["script"]), "bytes", flush=True)
            return self.responder(200, {"path": "universes/%s/places/%s/versions/%s/luau-execution-sessions/s1/tasks/%s" % (m.group(1), m.group(2), m.group(3), tid), "state": "QUEUED"})
        if self.path.endswith(":restartServers"):
            print("MOCK restart", flush=True)
            return self.responder(200, {})
        self.responder(404, {"message": "nao achei " + self.path})


HTTPServer(("127.0.0.1", int(ARGS[0])), H).serve_forever()
