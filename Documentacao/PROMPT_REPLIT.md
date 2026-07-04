# Prompt para o Replit Agent — Construção do Assistente Virtual de RH

> Cole o conteúdo abaixo (da linha `====` em diante) no **Replit Agent**.
> Ele constrói o projeto do zero, por etapas, evitando os erros conhecidos.
> Tenha em mãos a `OPENROUTER_API_KEY` para adicionar em **Secrets** quando solicitado.

====================================================================

Você é um engenheiro sênior de IA. Construa, **por etapas e validando cada uma antes de avançar**, uma aplicação web de atendimento de RH multiagente em Python. Não pule etapas. Ao final de cada etapa, rode uma verificação e só prossiga se ela passar. Escreva todo o conteúdo destinado ao usuário final em **Português do Brasil (pt-BR)**; o código (nomes de variáveis/funções) em inglês.

## Contexto do produto

Assistente de RH que responde dúvidas de colaboradores usando **LangGraph** (orquestração multiagente) + **RAG** (ChromaDB em memória) + interface **Streamlit**. As LLMs e os embeddings são acessados via **OpenRouter** (API compatível com OpenAI). Domínios atendidos: Benefícios, Segurança do Trabalho, Ambulatório, Folha de Pagamento e Férias, além de um recepcionista para saudações.

## Regras de ouro (para não quebrar)

1. **Ambiente:** use o módulo **Python 3.11** do Replit. NÃO defina `requires-python` acima de 3.11 em nenhum arquivo. Instale dependências via `requirements.txt` com `pip`.
2. **Chaves:** leia todas as credenciais de variáveis de ambiente com `os.getenv(...)` (via `python-dotenv` + Replit Secrets). NUNCA escreva chaves no código nem crie `.env` com valores reais versionados.
3. **Provedor único = OpenRouter:** tanto LLMs quanto embeddings usam `base_url="https://openrouter.ai/api/v1"` e `api_key=OPENROUTER_API_KEY`.
4. **Nomes de modelo:** use IDs válidos no OpenRouter com prefixo de provedor: chat `openai/gpt-4o-mini` (simples/médio) e `openai/gpt-4o` (complexo); embeddings `openai/text-embedding-3-small`.
5. **max_tokens ≥ 16** em qualquer chamada (provedores rejeitam valores menores).
6. **Resiliência:** a criação do vector store e do pool de LLMs deve estar protegida por `try/except`, lançando `RuntimeError` com mensagem clara (ex.: "verifique OPENROUTER_API_KEY e a conexão") em vez de deixar vazar traceback cru. NÃO use `exit()`/`sys.exit()` no nível de módulo.
7. **Streamlit no Replit:** execute com `--server.port 8080 --server.address 0.0.0.0 --server.headless true --server.enableCORS false --server.enableXsrfProtection false`.
8. **Prompts desacoplados:** os system prompts dos agentes ficam em arquivos `.md` na pasta `prompts/`, carregados por uma função `load_prompt(name, **kwargs)` com cache e placeholders `{variavel}`.

---

## ETAPA 1 — Scaffolding e dependências

1. Crie a estrutura:
   ```
   agent_rh.py
   app_streamlit.py
   requirements.txt
   .replit
   replit.nix
   prompts/
   RAG/{beneficios,seguranca,ambulatorio,folha_pagamento,ferias}/
   ```
2. `requirements.txt`:
   ```
   chromadb
   langchain
   langchain-chroma
   langchain-community
   langchain-openai
   langgraph
   pydantic
   python-dotenv
   pytz
   streamlit
   langfuse
   ```
3. `.replit` com `modules = ["python-3.11"]` e `run` do Streamlit usando as flags da regra 7 (porta 8080, address 0.0.0.0). Adicione `[[ports]]` mapeando `localPort = 8080` → `externalPort = 80`.
4. `replit.nix` incluindo `pkgs.python311`, `pkgs.python311Packages.pip` e `pkgs.stdenv.cc.cc.lib` (necessário para onnxruntime/chromadb), definindo `LD_LIBRARY_PATH`.
5. Instale as dependências: `pip install -r requirements.txt`.

**Verificação E1:** `python -c "import langgraph, langchain_openai, langchain_chroma, chromadb, streamlit, pytz; print('deps ok')"` deve imprimir `deps ok`.

---

## ETAPA 2 — Base de conhecimento (dados de exemplo)

Crie arquivos de exemplo (conteúdo fictício, em pt-BR) para permitir testes:

- `RAG/beneficios/plano_saude.txt`, `RAG/beneficios/vale_refeicao.txt`
- `RAG/seguranca/epis.txt`, `RAG/seguranca/acidentes.txt`
- `RAG/ambulatorio/atestados.txt`, `RAG/ambulatorio/horarios.txt`
- `RAG/folha_pagamento/salario.txt`
- `RAG/ferias/ferias.csv` (colunas ex.: `colaborador,periodo_aquisitivo,dias_disponiveis,observacao`, com ~5 linhas)

Cada `.txt` deve ter título e alguns tópicos objetivos (valor, prazo, procedimento, contato).

**Verificação E2:** liste os arquivos e confirme que cada pasta de `RAG/` tem ao menos 1 arquivo.

---

## ETAPA 3 — Utilitários: tempo, prompts e telemetria

Em `agent_rh.py`:

1. `load_dotenv()` no topo.
2. Funções de tempo com `pytz` (`America/Sao_Paulo`): `get_sao_paulo_time()`, `get_contextual_greeting()` (Bom dia/Boa tarde/Boa noite), `get_formatted_time()`.
3. `load_prompt(name, **kwargs)`: lê `prompts/{name}.md`, cacheia, aplica `.format(**kwargs)`; erro claro se o arquivo não existir.
4. Telemetria opcional Langfuse: `get_langfuse_callback()` retorna `CallbackHandler` se `LANGFUSE_PUBLIC_KEY` e `LANGFUSE_SECRET_KEY` existirem (dentro de `try/except`), senão `None`; `get_run_config()` retorna `{"callbacks":[cb]}` ou `{}`.

**Verificação E3:** `python -c "import agent_rh"` importa sem erro (ainda sem chamadas de rede).

---

## ETAPA 4 — Loaders de documentos e vector store

1. `load_documents_from_directory(dir, category)`: 1 `Document` por `.txt`, com metadados `source, category, file_path, version`.
2. `load_csv_documents(dir, category)`: 1 `Document` por linha (`coluna: valor | ...`), detectando delimitador; metadados incluem `row`.
3. Carregue todas as categorias, concatene em `all_documents` e imprima a contagem.
4. Configure embeddings via OpenRouter (regra 3 e 4). Crie o `Chroma.from_documents(...)` com `collection_name="rh_knowledge_base"`, **dentro de try/except** (regra 6).

**Verificação E4:** com `OPENROUTER_API_KEY` já em Secrets, `python -c "import agent_rh"` deve logar "documentos carregados" e "Vector store criado com sucesso". Se a chave faltar, deve aparecer a mensagem clara de erro (não um traceback da SDK).

> Se a chave ainda não estiver configurada, PARE e peça ao usuário para adicionar o Secret `OPENROUTER_API_KEY` antes de continuar.

---

## ETAPA 5 — Pool de LLMs e modelos Pydantic

1. `_build_llm(level)` → `ChatOpenAI` no OpenRouter para níveis `simple` (temp 0.0, max_tokens 300), `medium` (0.3, 250), `complex` (0.0, 500). Modelos lidos de `LLM_SIMPLE_MODEL`/`LLM_MEDIUM_MODEL`/`LLM_COMPLEX_MODEL` com defaults da regra 4. Proteja com try/except (regra 6).
2. Instancie `llm_simple`, `llm_medium`, `llm_complex` e alias `llm = llm_complex`.
3. Modelos Pydantic: `InitialRouter` (`next_node`: receptionist|classifier), `MessageClassifier` (`message_type`: benefits|safety|clinic|payroll|vacation), `RewrittenQueries` (`queries`: lista de 3).

**Verificação E5:** um teste rápido: instanciar `llm_simple` e fazer `llm_simple.invoke("diga ok")` retornando texto (confirma OpenRouter + modelo válido).

---

## ETAPA 6 — Grafo LangGraph

1. `State` (TypedDict): `messages (add_messages)`, `message_type`, `next_node`, `retrieved_context`, `rewritten_queries`, `current_time`, `greeting`.
2. Nós:
   - `route_initial_message` (usa `llm_simple` + `InitialRouter`; injeta saudação/horário)
   - `receptionist_agent` (`llm_simple`)
   - `classify_message` (`llm_simple` + `MessageClassifier`)
   - `rewrite_query` (`llm_medium` + `RewrittenQueries`, com vocabulário por categoria)
   - `retrieve_knowledge` (busca multi-query: original + reescritas; `similarity_search_with_score(q, k=3)`; dedup por (source, trecho); top-4 por similaridade `1-distance`; monta contexto com fonte/categoria/score)
   - `benefits_agent`, `safety_agent`, `clinic_agent`, `payroll_agent`, `vacation_agent` (todos `llm` complexo, recebendo `context`)
3. Arestas:
   ```
   START → initial_router
   initial_router → {receptionist | classifier}   (por next_node)
   classifier → rewrite_query                       (qualquer message_type)
   rewrite_query → retrieve_knowledge
   retrieve_knowledge → {benefits|safety|clinic|payroll|vacation}  (por message_type)
   {receptionist, benefits, safety, clinic, payroll, vacation} → END
   ```
4. `app = graph_builder.compile()`.

**Verificação E6:** `app.invoke({"messages":[{"role":"user","content":"Quantos dias de férias eu tenho?"}]}, config=get_run_config())` retorna uma resposta em pt-BR sem exceção.

---

## ETAPA 7 — Prompts dos agentes

Crie em `prompts/` os arquivos `.md`: `initial_router`, `receptionist`, `classifier`, `query_rewriter`, `benefits_agent`, `safety_agent`, `clinic_agent`, `payroll_agent`, `vacation_agent`.

- Agentes especializados devem: responder só com base no `{context}` fornecido, citar quando não houver informação, tom cordial, pt-BR. Usar placeholders `{greeting}`, `{current_time}`, `{context}`, `{category}`, `{vocabulary}` conforme o nó.

**Verificação E7:** re-rode a verificação E6 e confirme que a resposta usa o contexto recuperado.

---

## ETAPA 8 — Interface Streamlit

Em `app_streamlit.py`:

1. Importe de `agent_rh`: `app`, helpers de tempo, `get_run_config`, `all_documents`.
2. `st.set_page_config(...)`, título, sidebar com: lista de agentes, saudação/horário, estatísticas (mensagens e agentes consultados), botão "Limpar Conversa", e contagem **dinâmica** de documentos (`len(all_documents)`).
3. Chat: `st.chat_input`, histórico em `st.session_state.messages`, e para cada pergunta `app.invoke(..., config=get_run_config())`; exiba badge do agente (`message_type`) e a resposta. Envolva a chamada em `try/except` mostrando erro amigável.

**Verificação E8:** rode o comando de Run; a aba Webview deve abrir a interface e responder a "Como funciona o vale-refeição?".

---

## ETAPA 9 — Fechamento

1. Gere um `README.md` curto (como rodar, Secrets necessários, estrutura).
2. Confirme o checklist final:
   - [ ] `pip install -r requirements.txt` sem erros
   - [ ] Secret `OPENROUTER_API_KEY` configurado
   - [ ] Import do módulo loga base carregada + vector store criado
   - [ ] `app.invoke(...)` responde em pt-BR
   - [ ] Webview abre e responde perguntas dos 5 domínios + saudação
3. (Opcional) Configure **Deploy** Autoscale/Cloud Run reutilizando o mesmo comando de Run.

## Secrets a solicitar ao usuário

- `OPENROUTER_API_KEY` (obrigatório)
- `LLM_SIMPLE_MODEL=openai/gpt-4o-mini`, `LLM_MEDIUM_MODEL=openai/gpt-4o-mini`, `LLM_COMPLEX_MODEL=openai/gpt-4o` (recomendado)
- `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST` (opcional, telemetria)

Comece pela **ETAPA 1** agora. Ao concluir cada etapa, informe o resultado da verificação e só então avance.
