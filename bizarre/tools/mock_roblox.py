#!/usr/bin/env python3
"""Open Cloud falsa (só para testar o instalador do BIZARRE sem tocar no Roblox).
uso: python3 bizarre/tools/mock_roblox.py PORTA [--falhar]
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

ESTADO = {"versao": 40, "tarefas": {}, "places": [], "falhar": "--falhar" in sys.argv, "ultimo_place": ""}
UNIVERSE = "10774214555"


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
        if self.path.endswith("/logs?maxPageSize=200"):
            return self.responder(200, {"luauExecutionSessionTaskLogs": [{"messages": ["log de teste"]}]})
        m = re.match(r"/cloud/v2/(universes/.+/tasks/(\w+))$", self.path)
        if m:
            t = ESTADO["tarefas"][m.group(2)]
            t["consultas"] += 1
            if t["consultas"] < 2:
                return self.responder(200, {"path": m.group(1), "state": "PROCESSING"})
            if "C.REVISAO" in t["script"]:
                rev = re.search(r'Config.REVISAO = "([^"]+)"', ESTADO["ultimo_place"])
                res = json.dumps({"revisao": rev.group(1) if rev else "?"})
            elif ESTADO["falhar"]:
                res = json.dumps({"ok": False, "erros": ["golpe AXE_ULT deu erro: simulado"], "avisos": [], "info": {}})
            else:
                res = json.dumps({"ok": True, "erros": [], "avisos": ["BOSSA_NOVA_ULT não acertou o boneco de teste"], "info": {
                    "modulos": 30, "revisao": "AJUSTE-1", "pecasMapa": 2100, "quebraveis": 1788,
                    "quebraTeste": "41 peças quebraram e 41 voltaram",
                    "stands": {"MARACATU": "catálogo:bombado, juntas 15", "BOSSA_NOVA": "catálogo:guerreiro, juntas 15", "FREVO": "reserva, juntas 15",
                               "AXE": "catálogo:super, juntas 15", "CHORINHO": "catálogo:musculoso, juntas 15", "FUNK": "catálogo:forte, juntas 15"},
                    "m1": "14.0 de dano, ragdoll true", "golpes": {"MARACATU_1": "18.3", "AXE_1": "11.0", "CHORINHO_1": "curou 24"},
                    "sons": "49/50"}})
            return self.responder(200, {"path": m.group(1), "state": "COMPLETE", "output": {"results": [res]}})
        self.responder(404, {"message": "nao achei " + self.path})

    def do_POST(self):
        if self.headers.get("x-api-key") != "CHAVE-DE-TESTE":
            return self.responder(401, {"message": "chave errada"})
        corpo = self.corpo()
        m = re.match(r"/universes/v1/(\d+)/places/(\d+)/versions\?versionType=(\w+)", self.path)
        if m:
            assert self.headers.get("Content-Type") == "application/xml"
            assert m.group(1) == UNIVERSE and m.group(2) == "108061345551908", self.path
            txt = corpo.decode("utf-8")
            assert "<roblox" in txt and "BB_Servidor" in txt, "place sem o servidor"
            ESTADO["ultimo_place"] = txt
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


HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
