# PRD — Assistente Virtual de RH (CPQD)

> **Product Requirements Document**
> Versão 1.0 · Idioma do produto: Português do Brasil (pt-BR)

---

## 1. Visão Geral

O **Assistente Virtual de RH** é um sistema de atendimento automatizado que responde
dúvidas de colaboradores sobre Recursos Humanos. Utiliza uma arquitetura **multiagente
com LangGraph** e **RAG (Retrieval-Augmented Generation)** para gerar respostas
fundamentadas em documentos internos da empresa (políticas, normas, tabelas de férias etc.).

A interface é uma aplicação web em **Streamlit** onde o colaborador conversa em linguagem
natural. O sistema identifica automaticamente o tema da pergunta, busca o contexto
relevante na base de conhecimento e responde com um agente especializado.

## 2. Problema e Objetivo

**Problema:** o RH recebe grande volume de perguntas repetitivas (benefícios, férias,
atestados, folha), gerando fila de atendimento e respostas inconsistentes.

**Objetivo:** oferecer autoatendimento 24/7, com respostas rápidas, consistentes e
rastreáveis à documentação oficial, reduzindo a carga sobre a equipe de RH.

## 3. Público-Alvo

- **Colaboradores da empresa** — usuários finais que fazem perguntas.
- **Equipe de RH** — mantém a base de conhecimento (arquivos `.txt`/`.csv`).
- **Time técnico** — opera, monitora (telemetria) e evolui o sistema.

## 4. Escopo dos Domínios Atendidos

| Domínio               | Agente         | Exemplos de perguntas                                       |
| --------------------- | -------------- | ----------------------------------------------------------- |
| Benefícios            | `benefits`     | plano de saúde, vale-refeição, vale-transporte, dependentes |
| Segurança do Trabalho | `safety`       | EPIs, acidentes, CAT, NRs, treinamentos                     |
| Ambulatório           | `clinic`       | atestados, exames periódicos, ASO, horários                 |
| Folha de Pagamento    | `payroll`      | salário, holerite, 13º, rescisão, FGTS/INSS                 |
| Férias                | `vacation`     | período aquisitivo/concessivo, abono, venda de férias       |
| Saudações / geral     | `receptionist` | "olá", "bom dia", orientação inicial                        |

## 5. Requisitos Funcionais

- **RF-01** — Receber perguntas em linguagem natural (pt-BR) via chat web.
- **RF-02** — Rotear a mensagem entre "recepcionista" (saudação/geral) e "classificador" (dúvida objetiva).
- **RF-03** — Classificar a dúvida em uma das 5 categorias de RH.
- **RF-04** — Reescrever a pergunta em variações (query rewriting) para melhorar a busca semântica.
- **RF-05** — Recuperar contexto relevante da base vetorial via busca multi-query com score.
- **RF-06** — Gerar a resposta final com o agente especializado, usando o contexto recuperado.
- **RF-07** — Exibir na interface qual agente respondeu (badge) e estatísticas de uso.
- **RF-08** — Saudação contextual por horário (bom dia/tarde/noite) no fuso `America/Sao_Paulo`.
- **RF-09** — Carregar automaticamente a base de conhecimento de arquivos `.txt` e `.csv` na inicialização.
- **RF-10** — Telemetria opcional de traces de LLM (Langfuse) quando credenciais estiverem presentes.

## 6. Requisitos Não Funcionais

- **RNF-01 (Idioma):** todo conteúdo gerado ao usuário em pt-BR.
- **RNF-02 (Custo):** seleção de modelo por complexidade da tarefa (simples/médio/complexo) para equilibrar custo x qualidade.
- **RNF-03 (Resiliência):** falha ao criar o vector store deve produzir mensagem clara, sem derrubar a aplicação com traceback cru.
- **RNF-04 (Configurabilidade):** provedores, modelos e chaves definidos por variáveis de ambiente, sem hardcode.
- **RNF-05 (Manutenibilidade):** prompts dos agentes desacoplados do código, em arquivos `.md`.
- **RNF-06 (Portabilidade):** executável localmente e em plataformas cloud (ex.: Replit) sem alteração de código.
- **RNF-07 (Observabilidade):** logs no console indicando carregamento da base, criação do vector store e roteamento.

## 7. Fluxo do Usuário (alto nível)

```
Usuário → Router inicial
          ├─ saudação/geral → Recepcionista → Resposta
          └─ dúvida objetiva → Classificador → Reescrita de query
                                              → Busca RAG (multi-query)
                                              → Agente especializado → Resposta
```

## 8. Métricas de Sucesso

- Taxa de perguntas respondidas sem escalonamento humano.
- Aderência da resposta à documentação (validação por amostragem).
- Tempo médio de resposta por pergunta.
- Distribuição de uso por agente (via estatísticas da sidebar / Langfuse).

## 9. Fora de Escopo (v1)

- Autenticação/identificação individual do colaborador.
- Persistência de histórico entre sessões (o histórico é apenas de sessão do Streamlit).
- Integração com sistemas de RH transacionais (folha, ponto).
- Ações que alterem dados (o sistema é somente consultivo).

## 10. Riscos e Mitigações

| Risco                                                         | Mitigação                                                     |
| ------------------------------------------------------------- | ------------------------------------------------------------- |
| Chave de API inválida/expirada derruba o app na inicialização | Tratamento de erro claro na criação do vector store (RNF-03)  |
| Provedor de embeddings indisponível                           | Mensagem acionável + possibilidade de trocar provedor via env |
| Base de conhecimento desatualizada                            | Processo de curadoria pelo RH; reindexação ao reiniciar       |
| Alucinação do LLM                                             | RAG com citação de fonte/score; prompts restritos ao contexto |
