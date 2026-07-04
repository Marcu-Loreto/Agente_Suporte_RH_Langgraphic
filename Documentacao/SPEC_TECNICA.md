# Especificação Técnica — Assistente Virtual de RH (CPQD)

> Documento de referência para **replicar e manter** o sistema.
> Base: `agent_rh_4_agentes.py`, `app_streamlit.py`, `prompts/`, `RAG/`.

---

## 1. Stack

| Camada                  | Tecnologia                                             |
| ----------------------- | ------------------------------------------------------ |
| Linguagem               | Python 3.11+ (projeto usa 3.13; funciona em 3.11/3.12) |
| Orquestração de agentes | LangGraph (`StateGraph`)                               |
| Framework LLM           | LangChain + `langchain-openai`                         |
| LLMs                    | Via **OpenRouter** (API compatível com OpenAI)         |
| Embeddings              | `text-embedding-3-small` via OpenRouter                |
| Vector store            | ChromaDB (`langchain-chroma`), em memória              |
| Interface               | Streamlit                                              |
| Telemetria (opcional)   | Langfuse                                               |
| Config                  | `python-dotenv` + variáveis de ambiente                |
| Fuso/tempo              | `pytz` (`America/Sao_Paulo`)                           |

## 2. Arquitetura do Grafo (LangGraph)

Estado compartilhado (`State`, um `TypedDict`):

```python
class State(TypedDict):
    messages: Annotated[list, add_messages]
    message_type: str | None       # benefits|safety|clinic|payroll|vacation
    next_node: str | None          # receptionist|classifier
    retrieved_context: str | None  # contexto RAG concatenado
    rewritten_queries: list[str] | None
    current_time: str | None
    greeting: str | None
```

### Nós

| Nó                                                | Função                                                         | LLM usado             |
| ------------------------------------------------- | -------------------------------------------------------------- | --------------------- |
| `initial_router`                                  | Decide `receptionist` vs `classifier`; injeta saudação/horário | `llm_simple`          |
| `receptionist`                                    | Responde saudações e orienta                                   | `llm_simple`          |
| `classifier`                                      | Classifica em 1 das 5 categorias                               | `llm_simple`          |
| `rewrite_query`                                   | Gera 3 variações da pergunta (query expansion)                 | `llm_medium`          |
| `retrieve_knowledge`                              | Busca multi-query no Chroma, deduplica, top-4 por score        | — (embeddings)        |
| `benefits`/`safety`/`clinic`/`payroll`/`vacation` | Resposta final especializada com contexto                      | `llm_complex` (`llm`) |

### Arestas

```
START → initial_router
initial_router → (next_node) → {receptionist | classifier}
classifier → (message_type) → rewrite_query
rewrite_query → retrieve_knowledge
retrieve_knowledge → (message_type) → {benefits|safety|clinic|payroll|vacation}
{receptionist, benefits, safety, clinic, payroll, vacation} → END
```

Compilação: `app = graph_builder.compile()` — exposto também em `langgraph.json`
como grafo `rh_4_agentes` (`agent_rh_4_agentes:app`).

## 3. Pool de LLMs por Complexidade

Função `_build_llm(level)` cria instâncias `ChatOpenAI` apontando para OpenRouter
(`base_url="https://openrouter.ai/api/v1"`, `api_key=OPENROUTER_API_KEY`).

| Nível     | Var. de modelo (.env) | Padrão          | temperature | max_tokens | Uso                                 |
| --------- | --------------------- | --------------- | ----------- | ---------- | ----------------------------------- |
| `simple`  | `LLM_SIMPLE_MODEL`    | `gpt-3.5-turbo` | 0.0         | 300        | roteamento, classificação, saudação |
| `medium`  | `LLM_MEDIUM_MODEL`    | `gpt-4-turbo`   | 0.3         | 250        | query rewriting                     |
| `complex` | `LLM_COMPLEX_MODEL`   | `gpt-4o`        | 0.0         | 500        | respostas finais                    |

> **Nota Replit/OpenRouter:** nomes de modelo devem ser válidos no OpenRouter.
> Recomenda-se o formato com prefixo de provedor, ex.: `openai/gpt-4o-mini`.
> `max_tokens` mínimo aceito por alguns provedores é 16.

## 4. Base de Conhecimento (RAG)

Diretório raiz: `RAG/`. Carregamento na **inicialização do módulo**.

| Categoria | Pasta                  | Formato | Loader                                      |
| --------- | ---------------------- | ------- | ------------------------------------------- |
| benefits  | `RAG/beneficios/`      | `.txt`  | `load_documents_from_directory`             |
| safety    | `RAG/seguranca/`       | `.txt`  | idem                                        |
| clinic    | `RAG/ambulatorio/`     | `.txt`  | idem                                        |
| payroll   | `RAG/folha_pagamento/` | `.txt`  | idem                                        |
| vacation  | `RAG/ferias/`          | `.csv`  | `load_csv_documents` (1 Document por linha) |

- `.txt` → 1 `Document` por arquivo (todo o conteúdo).
- `.csv` → 1 `Document` por linha, no formato `coluna: valor | coluna: valor` (delimitador detectado automaticamente).
- Metadados por documento: `source`, `category`, `file_path`, `version` (e `row` para CSV).

### Recuperação (`retrieve_knowledge`)

1. Monta lista de queries: original + reescritas (deduplicadas).
2. Para cada query: `vectorstore.similarity_search_with_score(q, k=3)`.
3. Converte distância em similaridade (`1 - distance`), deduplica por `(source, trecho)`, mantém melhor score.
4. Ordena desc. e seleciona **top 4**; monta o contexto com fonte, categoria, versão e score.

## 5. Prompts Externos

Diretório `PROMPTS_DIR` (padrão `./prompts`). Carregados por `load_prompt(name, **kwargs)`
com cache em memória. Placeholders no formato `{variavel}` (use `{{ }}` para chave literal).

Arquivos esperados: `initial_router.md`, `receptionist.md`, `classifier.md`,
`query_rewriter.md`, `benefits_agent.md`, `safety_agent.md`, `clinic_agent.md`,
`payroll_agent.md`, `vacation_agent.md`.

Variáveis interpoladas comuns: `greeting`, `current_time`, `context`, `category`, `vocabulary`.

## 6. Interface (Streamlit — `app_streamlit.py`)

- Importa `app`, helpers de tempo, `get_run_config` e `all_documents` do módulo do agente.
- Mantém histórico em `st.session_state.messages` e `agent_history`.
- A cada mensagem: `app.invoke({"messages":[...]}, config=get_run_config())`.
- Exibe badge do agente (`message_type`) e efeito de digitação.
- Sidebar: agentes, saudação/horário, estatísticas e contagem real de documentos.

## 7. Telemetria (opcional)

`get_langfuse_callback()` retorna um `CallbackHandler` se `LANGFUSE_PUBLIC_KEY` e
`LANGFUSE_SECRET_KEY` existirem; caso contrário, `None` (roda sem telemetria).
`get_run_config()` injeta o callback em `config={"callbacks":[...]}`.

## 8. Variáveis de Ambiente

| Variável                              | Obrigatória | Descrição                                 |
| ------------------------------------- | ----------- | ----------------------------------------- |
| `OPENROUTER_API_KEY`                  | **Sim**     | Chave OpenRouter (LLMs + embeddings)      |
| `LLM_SIMPLE_MODEL`                    | Não         | Modelo nível simples                      |
| `LLM_MEDIUM_MODEL`                    | Não         | Modelo nível médio                        |
| `LLM_COMPLEX_MODEL`                   | Não         | Modelo nível complexo                     |
| `PROMPTS_DIR`                         | Não         | Diretório de prompts (padrão `./prompts`) |
| `LANGFUSE_PUBLIC_KEY`                 | Não         | Telemetria                                |
| `LANGFUSE_SECRET_KEY`                 | Não         | Telemetria                                |
| `LANGFUSE_HOST` / `LANGFUSE_BASE_URL` | Não         | Host do Langfuse                          |

## 9. Dependências

`requirements.txt`:

```
chromadb
langchain
langchain-chroma
langchain-community
langchain-openai
langfuse
langgraph
langgraph-cli[inmem]
pydantic
python-dotenv
pytz
streamlit
```

> Embeddings locais do Chroma (fallback) exigem `onnxruntime` e `tokenizers`, já
> presentes como dependências transitivas do `chromadb`.

## 10. Execução

| Modo                    | Comando                          |
| ----------------------- | -------------------------------- |
| Interface web           | `streamlit run app_streamlit.py` |
| CLI / testes            | `python agent_rh_4_agentes.py`   |
| Studio (debug do grafo) | `langgraph dev`                  |
| Tudo (script)           | `bash run_completo.sh`           |

## 11. Pontos de Atenção / Dívida Técnica

- Inicialização pesada (base + vector store + LLMs) ocorre **no import** do módulo.
- Existem `exit(1)` no nível de módulo para chave ausente — em ambientes web geram encerramento abrupto; preferir tratamento amigável.
- Vector store é **em memória**; reindexado a cada boot. Para persistir, usar `persist_directory`.
- Sem autenticação — não expor publicamente sem uma camada de acesso.
