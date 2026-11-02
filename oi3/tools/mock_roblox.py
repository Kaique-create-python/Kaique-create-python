#!/usr/bin/env python3
"""Servidor falso da Open Cloud, só para testar o instalador sem tocar no Roblox."""
import json, sys, re
from http.server import BaseHTTPRequestHandler, HTTPServer
from email.parser import BytesParser
from email.policy import default

ESTADO = {"ops": {}, "versao": 10, "tarefas": {}, "uploads": [], "places": [], "falhar_teste": "--falhar" in sys.argv,
          "sem_permissao": "--sem-permissao" in sys.argv, "bloquear": "--bloquear" in sys.argv, "liberados": set()}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def responder(self, codigo, obj):
        corpo = json.dumps(obj).encode()
        self.send_response(codigo); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(corpo))); self.end_headers(); self.wfile.write(corpo)
    def corpo(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n)
    def do_GET(self):
        if self.headers.get("x-api-key") is None and not self.path.startswith("/v1/games"):
            return self.responder(401, {"message": "sem chave"})
        if self.path.startswith("/v1/games"):
            return self.responder(200, {"data": [{"name": "OI3", "creator": {"id": 1357078972, "name": "dono", "type": "User"}}]})
        m = re.match(r"/assets/v1/assets/(\d+)\?readMask=moderationResult", self.path)
        if m:
            # final par = aprovado, ímpar = em análise (só para variar no teste)
            estado = "Approved" if int(m.group(1)[-1]) % 2 == 0 else "Reviewing"
            return self.responder(200, {"assetId": m.group(1), "moderationResult": {"moderationState": estado}})
        m = re.match(r"/assets/v1/operations/(\w+)", self.path)
        if m:
            op = ESTADO["ops"][m.group(1)]
            op["consultas"] += 1
            if op["consultas"] >= 2:
                return self.responder(200, {"path": "operations/" + m.group(1), "done": True, "response": {"assetId": op["id"], "moderationResult": {"moderationState": "Reviewing"}}})
            return self.responder(200, {"path": "operations/" + m.group(1), "done": False})
        if self.path.endswith("/logs?maxPageSize=200"):
            return self.responder(200, {"luauExecutionSessionTaskLogs": [{"messages": ["log de teste"]}]})
        m = re.match(r"/cloud/v2/(universes/.+/tasks/(\w+))$", self.path)
        if m:
            t = ESTADO["tarefas"][m.group(2)]
            t["consultas"] += 1
            if t["consultas"] < 2:
                return self.responder(200, {"path": m.group(1), "state": "PROCESSING"})
            if "C.REVISAO" in t["script"]:
                rev = re.search(r'Config.REVISAO = "([^"]+)"', ESTADO.get("ultimo_place", ""))
                ids = dict(re.findall(r"\t\t(\w+) = (\d+),", ESTADO.get("ultimo_place", "").split("--@@OI3_RECURSOS_INICIO@@")[-1].split("--@@OI3_RECURSOS_FIM@@")[0]))
                res = json.dumps({"revisao": rev.group(1) if rev else "?", "audio": ids})
            elif ESTADO["falhar_teste"]:
                res = json.dumps({"ok": False, "erros": ["mapa: erro simulado"], "info": {}})
            else:
                ids = dict(re.findall(r"\t\t(\w+) = (\d+),", ESTADO.get("ultimo_place", "").split("--@@OI3_RECURSOS_INICIO@@")[-1].split("--@@OI3_RECURSOS_FIM@@")[0]))
                sons = {"_controle": 0.6}
                for k, v in ids.items():
                    sons[k] = -1 if (ESTADO["bloquear"] or int(v) not in ESTADO["liberados"]) else 12.5
                res = json.dumps({"ok": True, "erros": [], "info": {"modulos": 27, "pecasMapa": 1814, "pecasMenu": 195, "animacoesCarregadas": 4, "pecasLanterna": 11, "sons": sons}})
            return self.responder(200, {"path": m.group(1), "state": "COMPLETE", "output": {"results": [res]}})
        self.responder(404, {"message": "nao achei " + self.path})
    def do_PATCH(self):
        if self.headers.get("x-api-key") != "CHAVE-DE-TESTE":
            return self.responder(401, {"message": "chave errada"})
        corpo = self.corpo()
        if self.path == "/asset-permissions-api/v1/assets/permissions":
            if ESTADO["sem_permissao"]:
                return self.responder(403, {"error": {"code": "Forbidden", "message": "Insufficient scopes"}})
            d = json.loads(corpo.decode("utf-8"))
            assert self.headers.get("Content-Type") == "application/json", self.headers.get("Content-Type")
            assert d["subjectType"] == "Universe" and d["subjectId"] == "10774214680" and d["action"] == "Use", d
            ids = [int(r["assetId"]) for r in d["requests"]]
            ESTADO["liberados"].update(ids)
            print("MOCK liberou", ids, flush=True)
            return self.responder(200, {"successAssetIds": ids, "errors": []})
        self.responder(404, {"message": "nao achei " + self.path})
    def do_POST(self):
        if self.headers.get("x-api-key") != "CHAVE-DE-TESTE":
            return self.responder(401, {"message": "chave errada"})
        corpo = self.corpo()
        if self.path == "/assets/v1/assets":
            ct = self.headers.get("Content-Type")
            msg = BytesParser(policy=default).parsebytes(b"Content-Type: " + ct.encode() + b"\r\n\r\n" + corpo)
            partes = {p.get_param("name", header="content-disposition"): p for p in msg.iter_parts()}
            pedido = json.loads(partes["request"].get_content())
            arquivo = partes["fileContent"].get_payload(decode=True)
            assert pedido["assetType"] in ("Audio", "Image") and pedido["creationContext"]["creator"]["userId"] == "1357078972", pedido
            if pedido["assetType"] == "Audio":
                assert arquivo[:4] == b"OggS", "arquivo não é ogg"
            else:
                assert arquivo[:2] == b"\xff\xd8", "imagem não é jpeg"
            op = "op%d" % (len(ESTADO["ops"]) + 1)
            ESTADO["ops"][op] = {"consultas": 0, "id": str(9000 + len(ESTADO["ops"]) + 1)}
            ESTADO["uploads"].append((pedido["displayName"], len(arquivo)))
            print("MOCK upload", pedido["displayName"], len(arquivo), "bytes", flush=True)
            return self.responder(200, {"path": "operations/" + op, "operationId": op, "done": False})
        m = re.match(r"/universes/v1/(\d+)/places/(\d+)/versions\?versionType=(\w+)", self.path)
        if m:
            assert self.headers.get("Content-Type") == "application/xml"
            txt = corpo.decode("utf-8")
            assert "<roblox" in txt and "sfx = 90" in txt and "vozes1 = 90" in txt, "IDs não entraram no place"
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
