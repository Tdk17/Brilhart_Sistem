# Brilhart — Módulo Fiscal (Fase 2, fora do MVP)

## Escopo e regra de implantação

O MVP continua com orçamentos, ordens de serviço, produção, faturamento, contratos e documentos de fechamento. **Nenhuma rota existente deve emitir nota fiscal automaticamente.** Este documento planeja uma futura implementação fiscal independente, habilitada apenas após homologação.

O PDF de fechamento ou orçamento **não é nota fiscal**. O número fiscal, o XML autorizado e o documento auxiliar somente podem ser registrados após confirmação da autoridade fiscal.

## Tipo de documento

- **NFS-e (serviços):** integração com Emissor Nacional/API quando aplicável, com cadastro, credenciamento e certificado/credenciais do contribuinte conforme documentação vigente.
- **NF-e (mercadorias e operações sujeitas a ICMS):** implementação separada após avaliação contábil, fiscal e operacional. Não reutilizar o fluxo NFS-e.
- O contador deve confirmar CNAE, regime tributário, município de estabelecimento, descrição e classificação dos serviços, incidência tributária e eventual fornecimento de mercadorias.

Referências oficiais:
- https://www.gov.br/pt-br/servicos/emitir-nota-fiscal-de-servico-eletronica
- https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual

## Fluxo da NFS-e futura

1. Usuário autorizado seleciona um serviço concluído ou documento de faturamento elegível.
2. Prévia exibe cliente/tomador, CNPJ/CPF, endereço quando exigido, descrição, competência, valores e retenções conforme regra fiscal.
3. Backend valida completude e elegibilidade, evita duplicidade e registra solicitação em estado `draft`.
4. Usuário confirma e o backend cria a DPS, assina/transmite conforme exigências do ambiente e recebe o retorno.
5. Retorno autorizado: guardar número, chave/identificador fiscal, protocolo, XML e link/arquivo do DANFSe quando disponível, com auditoria.
6. Rejeição: guardar código/mensagem sem marcar como emitido; permitir corrigir e tentar novamente conforme legislação.
7. Cancelamento e substituição somente por fluxo próprio, respeitando autorização, prazo e eventos oficiais.

### Estados

`draft`, `validating`, `transmitting`, `authorized`, `rejected`, `cancel_requested`, `cancelled`, `substituted`.

## Modelo de dados sugerido (Parse)

### `FiscalInvoice`
`objectId`, `serviceId`, `clientId`, `issuerId`, `invoiceType` (NFS-e/NF-e), `status`, `competenceDate`, `issuedAt`, `grossAmount`, `taxes`, `serviceCode`, `description`, `externalReference`, `officialNumber`, `verificationCode`, `xmlStorageKey`, `danfseStorageKey`, `rejectionCode`, `rejectionMessage`, `createdBy`, `createdAt`, `updatedAt`.

### `FiscalEvent`
`invoiceId`, `type`, `status`, `requestedBy`, `protocol`, `rawResponseStorageKey`, `createdAt`.

### `FiscalSettings`
`issuerId`, `environment` (homologation/production), `taxRegime`, `municipalityCode`, `serviceCodes`, `providerType`, `enabled`, `credentialReference`. Segredos e certificado **nunca** ficam expostos no Flutter Web, em `dart-define` ou em classes públicas do Parse.

## API futura (Cloud Code em pasta `functions/`; registro central em `main.js`)

- `v1-fiscal-settings-get`: configuração pública interna sem segredos.
- `v1-fiscal-settings-update`: administrador, sem aceitar certificado em texto público.
- `v1-fiscal-invoices-list`: listagem paginada por serviço, cliente, período e status.
- `v1-fiscal-invoices-preview`: valida pré-requisitos e gera prévia, sem transmitir.
- `v1-fiscal-invoices-issue`: transmissão com idempotency key e bloqueio de concorrência.
- `v1-fiscal-invoices-status`: consulta status real e reconciliação.
- `v1-fiscal-invoices-xml`: download autenticado do XML autorizado.
- `v1-fiscal-invoices-document`: download autenticado do documento auxiliar.
- `v1-fiscal-invoices-cancel`: evento fiscal oficial, com permissão e justificativa.

Todos os endpoints privados devem conferir `request.user`, perfil de acesso, vínculo ao serviço, integridade dos valores, logs, rate limit e auditoria. Não chamar diretamente a autoridade fiscal do navegador.

## Frontend futuro

Rota futura `/fiscal/notas`, com tabela, filtros e status, prévia de emissão, confirmação explícita, rejeições, downloads e histórico. A navegação fiscal deve ficar oculta ou identificada como indisponível enquanto `FiscalSettings.enabled` for falso. **Não criar botão de emissão simulada.**

## Critérios de aceite para ativação

- Validação de dados cadastrais do emitente e tomador.
- Credenciamento e homologação junto ao emissor aplicável.
- Emissão e consulta reais homologadas.
- XML e documento auxiliar conferidos com o ambiente oficial.
- Idempotência; não emitir em duplicidade em caso de timeout.
- Tratamento de falha, rejeição, cancelamento e autorização.
- Certificados e segredos restritos ao backend.
- Auditoria e permissão por usuário.
- Aprovação fiscal/contábil antes da habilitação de produção.
