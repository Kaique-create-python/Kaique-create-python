#!/usr/bin/env python3
"""Consulta somente o teste da foto. Nao salva, nao testa novamente e nao publica."""
import getpass
import json
import warnings
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

# Identificador publico da tarefa mostrada por Kaique; nao e credencial.
TASK = ('universes/10774214555/places/108061345551908/versions/36/'
        'luau-execution-sessions/f04d1cb4-be11-40ae-adfc-23e06ead469c/'
        'tasks/f04d1cb4-be11-40ae-adfc-23e06ead469c')
URL = 'https://apis.roblox.com/cloud/v2/' + TASK
LIMIT = 2 * 1024 * 1024


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def consultar(key, opener=None):
    if not key:
        raise ValueError('Chave vazia.')
    opener = opener or build_opener(NoRedirect())
    request = Request(URL, headers={'x-api-key': key, 'Accept': 'application/json'}, method='GET')
    try:
        with opener.open(request, timeout=45) as response:
            raw = response.read(LIMIT + 1)
        if len(raw) > LIMIT:
            raise ValueError('Resposta acima do limite; nada foi alterado.')
        data = json.loads(raw)
        if data.get('state') != 'COMPLETE':
            result = {'estado': data.get('state'), 'erro': data.get('error', 'Resultado ainda indisponivel.')}
        else:
            results = data.get('output', {}).get('results', [])
            if not results:
                raise ValueError('Tarefa concluida sem relatorio de saida.')
            result = results[0]
            if isinstance(result, str):
                result = json.loads(result)
        return json.dumps(result, ensure_ascii=False, indent=2).replace(key, '[OCULTA]')
    except HTTPError as error:
        detail = error.read(2000).decode('utf8', 'replace').replace(key, '[OCULTA]')
        raise ValueError('HTTP ' + str(error.code) + ': ' + detail) from None
    except (URLError, OSError, ValueError) as error:
        raise ValueError(str(error).replace(key, '[OCULTA]')) from None


def main():
    key = ''
    print('Somente consulta do teste Saved 36. Nenhum envio/publicacao.')
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', getpass.GetPassWarning)
            key = getpass.getpass('Chave Open Cloud (oculta; nao salva): ').strip()
        print(consultar(key))
    except getpass.GetPassWarning:
        raise SystemExit('Terminal sem entrada oculta; nenhuma consulta foi feita.') from None
    except (ValueError, EOFError, KeyboardInterrupt) as error:
        raise SystemExit('ERRO: ' + str(error).replace(key, '[OCULTA]') if key else 'Consulta cancelada.') from None
    finally:
        key = ''


if __name__ == '__main__':
    main()
