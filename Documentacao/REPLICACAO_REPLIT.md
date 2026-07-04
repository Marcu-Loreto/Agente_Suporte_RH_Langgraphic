# Guia de Replicação no Replit

Passo a passo para rodar o **Assistente Virtual de RH** em um Repl (replit.com).

---

## 1. Criar o Repl

Escolha uma das opções:

**A) Importar do GitHub (recomendado)**

1. No Replit: **Create Repl → Import from GitHub**.
2. Cole a URL do repositório.
3. O Replit lê os arquivos `.replit` e `replit.nix` já incluídos neste projeto.

**B) Repl Python em branco + upload**

1. **Create Repl → Python**.
2. Faça upload de todos os arquivos e pastas do projeto, incluindo:
   - `agent_rh_4_agentes.py`, `app_streamlit.py`, `requirements.txt`
   - pastas `prompts/` e `RAG/` (essenciais)
   - `.replit` e `replit.nix` (deste projeto)

## 2. Configurar os Secrets

No painel esquerdo: **Tools → Secrets** (ícone de cadeado). Adicione:

| Key                   | Value                                    | Obrigatório |
| --------------------- | ---------------------------------------- | ----------- |
| `OPENROUTER_API_KEY`  | sua chave do OpenRouter (`sk-or-v1-...`) | **Sim**     |
| `LLM_SIMPLE_MODEL`    | `openai/gpt-4o-mini`                     | recomendado |
| `LLM_MEDIUM_MODEL`    | `openai/gpt-4o-mini`                     | recomendado |
| `LLM_COMPLEX_MODEL`   | `openai/gpt-4o`                          | recomendado |
| `PROMPTS_DIR`         | `./prompts`                              | opcional    |
| `LANGFUSE_PUBLIC_KEY` | chave pública (se usar telemetria)       | opcional    |
| `LANGFUSE_SECRET_KEY` | chave secreta (se usar telemetria)       | opcional    |
| `LANGFUSE_HOST`       | `https://cloud.langfuse.com`             | opcional    |

> Os Secrets do Replit são injetados como variáveis de ambiente. O código usa
> `os.getenv(...)`, então funcionam sem precisar de um arquivo `.env`.
> **Não** faça upload do seu `.env` real com chaves para um Repl público.

## 3. Instalar dependências

O Replit normalmente instala a partir do `requirements.txt` automaticamente.
Se necessário, rode no **Shell**:

```bash
pip install -r requirements.txt
```

> Se o `pip install .` falhar por causa de `requires-python = ">=3.13"` no
> `pyproject.toml`, use o `requirements.txt` (comando acima) — ele não impõe a versão.

## 4. Executar

Clique em **Run**. O comando definido em `.replit` sobe o Streamlit em
`0.0.0.0:8080`, que o Replit publica na aba **Webview**.

A URL pública terá o formato `https://<nome-do-repl>.<usuario>.repl.co`.

## 5. Publicar (Deployment) — opcional

Para manter online 24/7:

1. **Deploy** no topo da IDE.
2. Tipo sugerido: **Autoscale** (Cloud Run) — já pré-configurado em `.replit` (`deploymentTarget = "cloudrun"`).
3. Confirme que os Secrets também estão disponíveis no ambiente de deployment.

## 6. Verificação (checklist)

- [ ] Secret `OPENROUTER_API_KEY` definido.
- [ ] Pastas `prompts/` e `RAG/` presentes no Repl.
- [ ] `requirements.txt` instalado sem erro.
- [ ] Ao rodar, o log mostra: `Total de documentos carregados`, `Vector store criado com sucesso`, `Grafo RH compilado com sucesso`.
- [ ] Webview abre a interface e responde a uma pergunta de teste (ex.: "Quantos dias de férias eu tenho?").

## 7. Problemas comuns

| Sintoma                                                      | Causa provável                        | Solução                                                                                 |
| ------------------------------------------------------------ | ------------------------------------- | --------------------------------------------------------------------------------------- |
| App não abre / traceback de `AuthenticationError 401`        | `OPENROUTER_API_KEY` ausente/inválida | Revisar o Secret                                                                        |
| `400 ... integer below minimum value` em `max_output_tokens` | modelo com mínimo de tokens           | usar `max_tokens ≥ 16` (padrões do código já atendem)                                   |
| `BadRequestError` de modelo inexistente                      | nome de modelo inválido no OpenRouter | usar IDs válidos, ex.: `openai/gpt-4o-mini`                                             |
| Erro de `libstdc++`/`onnxruntime` ao importar Chroma         | libs nativas ausentes                 | garantir `replit.nix` deste projeto (inclui `stdenv.cc.cc.lib`)                         |
| Webview em branco                                            | porta incorreta                       | manter `--server.port 8080 --server.address 0.0.0.0`                                    |
| Página pede senha/CORS                                       | proteções do Streamlit                | flags `--server.enableCORS false --server.enableXsrfProtection false` (já no `.replit`) |

## 8. Observações de arquitetura no Replit

- O vector store (ChromaDB) é **em memória** e recriado a cada boot; isso é aceitável
  para a base atual (centenas de documentos). Para bases grandes, considere
  `persist_directory` e cache.
- A inicialização (carga da base + embeddings) roda no import; o primeiro start
  pode levar alguns segundos enquanto os embeddings são gerados via OpenRouter.
- Não há autenticação embutida — para uso interno, restrinja o acesso ao Repl/Deployment.
