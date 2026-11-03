"""
Cria os experimentos de exemplo, passando pela API de verdade.

    python dados/semear.py                # gera os gráficos e registra pela API
    python dados/semear.py --so-graficos  # só gera os arquivos, sem registrar

Este script faz o papel de "quem treina": roda modelos simples de previsão
fora do sistema (como no documento: o treino não acontece no Diário) e
registra cada rodada pela rota POST /experimentos, como a página faria.

Os modelos são propositalmente simples, só para dar números e gráficos reais
à demonstração. Não é o foco do projeto.

Também deixa prontos, em dados/graficos/demo/, os arquivos para a demonstração
ao vivo: uma rodada ainda não registrada e dois arquivos que devem ser recusados.
"""
import argparse
import base64
import json
import re
import sys
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

RAIZ = Path(__file__).resolve().parent.parent
PASTA = RAIZ / "dados" / "graficos"
DEMO = PASTA / "demo"
MESES_TESTE = 24


# ------------------------------------------------------------------ dados
def serie_bcb(codigo, quantidade=120):
    """Série do Banco Central (SGS). Volta None se não houver internet."""
    url = (f"https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados/ultimos/"
           f"{quantidade}?formato=json")
    try:
        with urllib.request.urlopen(url, timeout=8) as r:
            dados = json.load(r)
        datas = [d["data"][3:] for d in dados]  # "01/05/2024" -> "05/2024"
        valores = np.array([float(d["valor"]) for d in dados])
        return datas, valores
    except Exception:
        return None


def serie_ilustrativa(tipo, quantidade=120):
    """Série inventada, com cara de real, para quando não houver internet."""
    gerador = np.random.default_rng(42 if tipo == "inflacao" else 7)
    meses = [f"{(m % 12) + 1:02d}/{2016 + m // 12}" for m in range(quantidade)]
    if tipo == "inflacao":
        sazonal = 0.15 * np.sin(np.arange(quantidade) * 2 * np.pi / 12)
        valores, anterior = [], 0.4
        for s in sazonal:
            anterior = 0.4 + 0.55 * (anterior - 0.4) + gerador.normal(0, 0.18)
            valores.append(anterior + s)
        return meses, np.round(np.array(valores), 2)
    passos = gerador.normal(0.01, 0.12, quantidade)
    return meses, np.round(4.0 + np.cumsum(passos), 3)


PROJETOS = {
    "previsao-inflacao": {"codigo": 433, "tipo": "inflacao", "unidade": "IPCA, % ao mês",
                          "nome": "Inflação mensal (IPCA)"},
    "previsao-cambio": {"codigo": 3698, "tipo": "cambio", "unidade": "R$ por US$",
                        "nome": "Dólar comercial, média do mês"},
}


# ------------------------------------------------------------------ modelos (prévia simples)
def ingenuo(y, inicio):
    """Modelo de referência: repete o último valor observado."""
    return np.array([y[t - 1] for t in range(inicio, len(y))])


def media_movel(y, inicio, janela):
    return np.array([y[t - janela:t].mean() for t in range(inicio, len(y))])


def defasagens(y, p):
    X = np.array([y[t - p:t][::-1] for t in range(p, len(y))])
    return X, y[p:]


def regressao_ar(y, inicio, p):
    """Regressão linear sobre os p meses anteriores, ajustada só com o treino."""
    X, alvo = defasagens(y[:inicio], p)
    X1 = np.column_stack([np.ones(len(X)), X])
    coef, *_ = np.linalg.lstsq(X1, alvo, rcond=None)
    return np.array([coef[0] + coef[1:] @ y[t - p:t][::-1] for t in range(inicio, len(y))])


def random_forest(y, inicio, p, arvores, profundidade):
    from sklearn.ensemble import RandomForestRegressor
    X, alvo = defasagens(y[:inicio], p)
    modelo = RandomForestRegressor(n_estimators=arvores, max_depth=profundidade, random_state=42)
    modelo.fit(X, alvo)
    entradas = np.array([y[t - p:t][::-1] for t in range(inicio, len(y))])
    return modelo.predict(entradas)


def slug(texto):
    sem_acento = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", sem_acento.lower()).strip("-")[:70]


def rmse(real, previsto):
    return float(np.sqrt(np.mean((real - previsto) ** 2)))


# ------------------------------------------------------------------ gráfico
def desenhar(arquivo, projeto, info, datas, y, inicio, previsto, modelo, erro, fonte):
    fig, ax = plt.subplots(figsize=(9, 4.2), dpi=100)
    contexto = max(0, inicio - 24)
    xs = np.arange(len(y))
    ax.plot(xs[contexto:inicio + 1], y[contexto:inicio + 1], color="#9AA5B8", lw=1.6, label="histórico (treino)")
    ax.plot(xs[inicio:], y[inicio:], color="#14213D", lw=2.2, label="real (teste)")
    ax.plot(xs[inicio:], previsto, color="#E07A10", lw=2.2, ls="--", label="previsto pelo modelo")
    ax.axvline(inicio - 0.5, color="#C9D4E3", lw=1)
    passo = 6
    ax.set_xticks(xs[contexto::passo])
    ax.set_xticklabels([datas[i] for i in range(contexto, len(y), passo)], fontsize=8)
    ax.set_ylabel(info["unidade"])
    ax.set_title(f"{info['nome']} — {modelo}\nRMSE no teste ({MESES_TESTE} meses): "
                 f"{erro:.3f}".replace(".", ","), fontsize=11, loc="left")
    ax.grid(alpha=0.25)
    ax.legend(fontsize=8, loc="upper left", frameon=False)
    fig.text(0.01, 0.01, f"Projeto {projeto} · {fonte}", fontsize=7, color="#6B7385")
    fig.tight_layout()
    fig.savefig(arquivo)
    plt.close(fig)


# ------------------------------------------------------------------ API
def url_da_api():
    # o config.js e gerado pelo infra/07-site.sh, com o endereco da API
    arquivo = RAIZ / "app" / "site" / "config.js"
    achado = arquivo.exists() and re.search(r'apiUrl:\s*"([^"]+)"', arquivo.read_text(encoding="utf-8"))
    if not achado:
        sys.exit("✕ Ainda não existe app/site/config.js com o endereço da API. Rode antes: ./infra/deploy.sh")
    return achado.group(1)


def registrar(api, corpo):
    pedido = urllib.request.Request(f"{api}/experimentos", method="POST",
                                    data=json.dumps(corpo).encode("utf-8"),
                                    headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(pedido, timeout=60) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as erro:
        return erro.code, json.load(erro)


# ------------------------------------------------------------------ principal
def rodadas_do_projeto(projeto, tem_sklearn):
    if projeto == "previsao-cambio":
        return [("Ingênuo (repete o último valor)", "", lambda y, i: ingenuo(y, i)),
                ("Média móvel", "janela=3", lambda y, i: media_movel(y, i, 3))]
    rodadas = [("Ingênuo (repete o último valor)", "", lambda y, i: ingenuo(y, i)),
               ("Média móvel", "janela=3", lambda y, i: media_movel(y, i, 3)),
               ("Média móvel", "janela=12", lambda y, i: media_movel(y, i, 12)),
               ("Regressão linear (AR)", "defasagens=3", lambda y, i: regressao_ar(y, i, 3))]
    if tem_sklearn:
        rodadas.append(("Random Forest", "n_estimators=200, max_depth=4, defasagens=12",
                        lambda y, i: random_forest(y, i, 12, 200, 4)))
    else:
        rodadas.append(("Regressão linear (AR)", "defasagens=12", lambda y, i: regressao_ar(y, i, 12)))
    return rodadas


def main():
    argumentos = argparse.ArgumentParser()
    argumentos.add_argument("--so-graficos", action="store_true")
    so_graficos = argumentos.parse_args().so_graficos

    PASTA.mkdir(parents=True, exist_ok=True)
    DEMO.mkdir(parents=True, exist_ok=True)
    api = None if so_graficos else url_da_api()
    try:
        import sklearn  # noqa: F401
        tem_sklearn = True
    except ImportError:
        tem_sklearn = False

    ao_vivo = None
    for projeto, info in PROJETOS.items():
        serie = serie_bcb(info["codigo"])
        fonte = f"Fonte: Banco Central, série SGS {info['codigo']}" if serie else "série ilustrativa (sem internet)"
        datas, y = serie or serie_ilustrativa(info["tipo"])
        inicio = len(y) - MESES_TESTE
        print(f"\n▸ {projeto}: {len(y)} meses ({fonte}); teste nos últimos {MESES_TESTE}")

        rodadas = rodadas_do_projeto(projeto, tem_sklearn)
        for n, (modelo, hiper, prever) in enumerate(rodadas):
            previsto = prever(y, inicio)
            erro = rmse(y[inicio:], previsto)
            nome = slug(f"{projeto}-{n + 1}-{modelo}-{hiper}")
            ultima_inflacao = projeto == "previsao-inflacao" and n == len(rodadas) - 1
            arquivo = (DEMO / f"AO-VIVO-{slug(modelo)}.png") if ultima_inflacao else (PASTA / f"{nome}.png")
            desenhar(arquivo, projeto, info, datas, y, inicio, previsto, modelo, erro, fonte)
            valor = f"{erro:.3f}".replace(".", ",")  # com vírgula, como quem escreve o relatório

            if ultima_inflacao:
                ao_vivo = {"projeto": projeto, "modelo": modelo, "hiperparametros": hiper,
                           "metrica": "RMSE", "valor": valor, "arquivo": arquivo.name}
                print(f"   ◦ {modelo} {hiper}: RMSE {valor} → guardado para a demonstração ao vivo")
                continue
            if so_graficos:
                print(f"   ◦ {modelo} {hiper or '(sem hiperparâmetros)'}: RMSE {valor} → {arquivo.name}")
                continue

            corpo = {"projeto": projeto, "modelo": modelo, "hiperparametros": hiper, "metrica": "RMSE",
                     "valor": valor, "grafico": base64.b64encode(arquivo.read_bytes()).decode()}
            status, resposta = registrar(api, corpo)
            if status == 201:
                print(f"   ✓ {modelo} {hiper or '(sem hiperparâmetros)'}: RMSE {valor} → "
                      f"id {resposta['id_experimento']}")
            else:
                print(f"   ✕ {modelo}: {status} {resposta.get('erro')}")

    # arquivos para mostrar a recusa (RF-04)
    (DEMO / "RECUSA-nao-e-png.png").write_text("Isto é um texto com extensão .png, não uma imagem.\n",
                                               encoding="utf-8")
    ruido = np.random.default_rng(1).integers(0, 255, (940, 940, 3), dtype=np.uint8)
    plt.imsave(DEMO / "RECUSA-maior-que-2MB.png", ruido)

    roteiro = DEMO / "LEIA-ME-demo.txt"
    roteiro.write_text(
        "Rodada para registrar AO VIVO na apresentação:\n\n"
        f"  Projeto ............ {ao_vivo['projeto']}\n"
        f"  Modelo ............. {ao_vivo['modelo']}\n"
        f"  Hiperparâmetros .... {ao_vivo['hiperparametros']}\n"
        f"  Métrica ............ {ao_vivo['metrica']}\n"
        f"  Valor .............. {ao_vivo['valor']}\n"
        f"  Gráfico ............ {ao_vivo['arquivo']}\n\n"
        "Para mostrar a recusa (RF-04):\n"
        "  - digite 'baixo' no valor da métrica\n"
        "  - ou anexe RECUSA-nao-e-png.png\n"
        "  - ou anexe RECUSA-maior-que-2MB.png\n", encoding="utf-8")

    print(f"\n▸ Arquivos da demonstração ao vivo em {DEMO.relative_to(RAIZ)}")
    print(roteiro.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
