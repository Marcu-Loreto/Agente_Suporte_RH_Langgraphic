# 🚀 Guia Rápido de Execução

Você pode executar o Assistente de RH de 3 formas. Em todas, ative o ambiente
virtual primeiro:

```bash
# Linux / macOS
source .venv/bin/activate

# Windows (PowerShell)
.venv\Scripts\Activate.ps1
```

---

## 📌 Opção 1: Interface Web (Streamlit) — Recomendado

```bash
# Sobe o Streamlit em background (Linux/macOS)
bash run_completo.sh

# Para encerrar
bash stop_services.sh
```

Ou diretamente:

```bash
streamlit run app_streamlit.py
```

Acesse: **http://localhost:8501**

---

## 📌 Opção 2: Modo Interativo / Testes (linha de comando)

```bash
python agent_rh_4_agentes.py
```

O script roda testes de exemplo e, em seguida, abre um modo interativo.
Digite `sair` para encerrar.

---

## 📌 Opção 3: LangGraph Studio (debug visual do grafo)

```bash
langgraph dev
```

Acesse a interface de debug em **http://localhost:8123**.

---

## ⚠️ IMPORTANTE: Configurar a API Key

O sistema usa o **OpenRouter** para LLMs e embeddings. No arquivo `.env`:

```env
OPENROUTER_API_KEY=sk-or-v1-SUA_CHAVE_AQUI

# Recomendado: modelos com prefixo de provedor
LLM_SIMPLE_MODEL=openai/gpt-4o-mini
LLM_MEDIUM_MODEL=openai/gpt-4o-mini
LLM_COMPLEX_MODEL=openai/gpt-4o
```

Gere sua chave em: https://openrouter.ai/keys

> Rodando no Replit? Não use `.env`: configure `OPENROUTER_API_KEY` em
> **Tools → Secrets**. Veja `Documentacao/REPLICACAO_REPLIT.md`.

---

## 🧪 Exemplos de Perguntas

**Saudação:**

```
Olá, bom dia!
```

**Benefícios:**

```
Como funciona o vale-refeição?
```

**Férias:**

```
Quantos dias de férias eu tenho?
```

**Segurança do Trabalho:**

```
Sofri um acidente no trabalho, o que devo fazer?
```

---

**✨ Tudo pronto para usar!**
