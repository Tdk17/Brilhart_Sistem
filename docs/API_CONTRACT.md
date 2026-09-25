# BrilhArte Sistem — Contrato de API

Este documento define as Cloud Functions esperadas pelo frontend Flutter Web/PWA. O padrão é o mesmo usado nos projetos CormeX: frontend sem mocks, chamadas HTTP para Parse/Back4App e sessão via `X-Parse-Session-Token`.

## Convenções

- Base Parse: `https://parseapi.back4app.com`
- Endpoint: `POST /functions/<nome-da-funcao>`
- Headers: `X-Parse-Application-Id`, `X-Parse-Client-Key` quando aplicável e `X-Parse-Session-Token` nas rotas privadas.
- Resposta esperada: `{ "result": { ... } }`.
- Rotas internas devem validar sessão e autorização no backend.
- Não confiar em IDs, status, valores ou origem enviados pelo cliente sem validação.
- Operações de conversão precisam ser idempotentes para impedir duplicidade.

## 1. Autenticação

### `v1-auth-login`
Entrada:
```json
{"email":"usuario@empresa.com","password":"***"}
```
Saída:
```json
{"sessionToken":"...","objectId":"...","name":"...","email":"..."}
```
Não existe cadastro público. Usuários são criados pelo administrador no backend.

### `v1-auth-me`
Retorna o usuário da sessão atual.

### `v1-auth-logout`
Invalida/encerra a sessão quando suportado e confirma logout.

## 2. Dashboard

### `v1-dashboard-metrics`
Entrada opcional: `from`, `to`, `status`, `clientId`.

Saída sugerida:
```json
{
  "inProduction": 0,
  "lateServices": 0,
  "completedServices": 0,
  "revenue": 0,
  "newQuoteRequests": 0,
  "upcomingServices": [
    {"objectId":"...","clientName":"...","description":"...","dueDate":"2026-10-10"}
  ]
}
```

## 3. Clientes

### `v1-clients-list`
Filtros: `search`, paginação e filtros opcionais.

### `v1-clients-create`
Campos: `name`, `phone`, `cityAddress`.

### `v1-clients-update`
Campos: `id` + campos editáveis.

### `v1-clients-delete`
Entrada: `id`. O backend decide se a exclusão é permitida. Não excluir de forma destrutiva se houver vínculos obrigatórios; preferir inativação quando necessário.

### `v1-clients-detail`
Retorna ficha completa e histórico de solicitações, orçamentos, serviços, contratos, documentos e compartilhamentos.

## 4. Solicitações de orçamento do site

### `v1-quote-requests-create`
Rota pública com validação, rate limit e proteção contra abuso.

Entrada:
```json
{
  "name":"...",
  "phone":"...",
  "cityAddress":"...",
  "serviceType":"...",
  "description":"...",
  "measurements":"...",
  "photos":[{"name":"foto.jpg","contentType":"image/jpeg","base64":"..."}],
  "source":"Site"
}
```

O backend deve forçar/preservar `source = Site`, registrar data/hora e armazenar fotos de forma segura.

Status válidos: `Novo`, `Em atendimento`, `Aguardando cliente`, `Convertido em orçamento`, `Não convertido/Encerrado`.

### `v1-quote-requests-list`
Privada. Filtros: `search`, `status`, datas.

### `v1-quote-requests-set-status`
Entrada: `id`, `status`, `internalNotes` opcional.

### `v1-quote-requests-convert-client`
Entrada: `id`.
Deve procurar cliente existente pelo telefone/WhatsApp antes de criar. Retorna `clientId` e `created`.

### `v1-quote-requests-convert-quote`
Entrada: `id` e complementos do orçamento.
Deve reaproveitar os dados já informados, manter `requestId`, `origin = Site` e impedir segundo orçamento da mesma solicitação sem confirmação explícita.

## 5. Orçamentos oficiais

### `v1-quotes-list`
Filtros: `search`, `status`, `clientId`, `from`, `to`, `origin`.

### `v1-quotes-create`
Campos: `clientId`, `status`, `baseColor`, `serviceType`, `description`, `value`, `paymentMethod`, `dueDate`, `measurements`, `additionalMeasurements`, `origin`, `quoteRequestId` opcional.

### `v1-quotes-update`
Entrada: `id` + campos alterados.

### `v1-quotes-detail`
Retorna orçamento completo e rastreabilidade.

### `v1-quotes-pdf`
Entrada: `id`.
Gera PDF A4 usando `CompanySettings`. Retorna URL segura/temporária, por exemplo:
```json
{"pdfUrl":"https://..."}
```

O PDF deve usar logo, nome, razão social quando aplicável, CNPJ, endereço, e-mail, telefone, Pix, condições de pagamento e rodapé.

### `v1-quotes-convert-service`
Entrada: `id`.
Somente orçamento aprovado pode virar serviço. A operação precisa ser idempotente e retornar o `serviceId` já existente quando executada novamente.

## 6. Serviços / Produção

### `v1-services-list`
Filtros: `search`, `status`, `clientId`, datas e atrasados.

### `v1-services-create`
Campos: `clientId`, `quoteId` opcional, `description`, `serviceType`, `measurements`, `value`, `dueDate`, `status`, `origin`.

### `v1-services-update`
Entrada: `id` + campos editáveis. Registrar auditoria da mudança.

### `v1-services-complete`
Entrada: `id`. Define `status = Concluído` e registra `completedAt` no servidor.

Status: `Aguardando`, `Em Produção`, `Concluído`, `Cancelado`.

## 7. Faturamento

### `v1-billing-summary`
Entrada: `from`, `to`, filtros opcionais.

Saída sugerida:
```json
{
  "revenue": 0,
  "siteRevenue": 0,
  "approvedQuotes": 0,
  "convertedRequests": 0,
  "origins": [
    {"origin":"Site","count":0,"revenue":0},
    {"origin":"Manual","count":0,"revenue":0},
    {"origin":"WhatsApp","count":0,"revenue":0}
  ]
}
```

Uma mesma receita não pode ser contabilizada duas vezes.

## 8. Contratos

### `v1-contracts-list`
Filtros por cliente, serviço, orçamento, status e datas.

### `v1-contracts-create`
Campos: `clientId`, `serviceId`/`quoteId`, modelo/conteúdo, `status`.

### `v1-contracts-update`
Entrada: `id` + campos editáveis.

### `v1-contracts-pdf`
Gera PDF e retorna `pdfUrl`.

### `v1-contracts-upload-signed`
Recebe contrato assinado e vincula ao contrato existente.

Status: `Rascunho`, `Enviado`, `Aceito/Assinado`, `Cancelado`.

## 9. Documentos de fechamento e Central de Documentos

### `v1-documents-list`
Filtros: cliente, serviço, tipo, número, status e datas.

### `v1-documents-create`
Campos: `clientId`, `serviceId`, `type`, `number`, `date`, `value`, `note`, arquivo.

### `v1-documents-update`
Entrada: `id` + campos alterados.

### `v1-documents-download`
Retorna `downloadUrl` segura/temporária.

A emissão fiscal automática não faz parte do MVP. Nota/NFS-e automática só deve existir quando houver integração específica com provedor fiscal.

## 10. Configurações da empresa

### `v1-company-settings-get`
Saída:
```json
{
  "tradeName":"BrilhArte Laqueamentos",
  "legalName":"",
  "cnpj":"",
  "address":"",
  "email":"",
  "phone":"",
  "whatsapp":"",
  "pixKey":"",
  "paymentTerms":"",
  "documentFooter":"",
  "logoUrl":""
}
```

### `v1-company-settings-update`
Atualiza os mesmos campos. Somente usuário autorizado.

## 11. Compartilhamento e auditoria

### `v1-share-log-create`
Registra `clientId`, `documentId`, `channel = WhatsApp`, usuário, data e status. O envio automático não é obrigatório no MVP; o sistema pode abrir o WhatsApp/WhatsApp Web e registrar o compartilhamento confirmado pelo usuário.

### Auditoria
Criar registro para mudanças importantes em clientes, solicitações, orçamentos, serviços, contratos e documentos contendo usuário, data/hora, entidade, entidadeId, ação e dados relevantes antes/depois quando adequado.

## 12. Classes Parse sugeridas

- `_User`
- `Client`
- `QuoteRequest`
- `Quote`
- `Service`
- `Contract`
- `ClosingDocument`
- `ShareLog`
- `CompanySettings`
- `AuditLog`

## 13. Segurança mínima

- ACL/CLP coerentes; dados internos não devem ficar públicos.
- Cloud Functions privadas validam `request.user`.
- Senhas apenas pelo mecanismo de autenticação do Parse, nunca texto puro.
- Rate limit e validação na solicitação pública.
- Validar MIME, tamanho e quantidade de uploads.
- Normalizar telefone antes de deduplicação.
- Validar transições de status no servidor.
- Conversões idempotentes e protegidas contra corrida.
- Valores de faturamento derivados do backend, não confiados ao frontend.
- URLs de arquivos privadas ou temporárias quando houver dados de cliente.

## 14. Variáveis do frontend

Build:
```bash
flutter build web --release \
  --base-href "/Brilhart_Sistem/" \
  --dart-define=APP_ENV=production \
  --dart-define=PARSE_APPLICATION_ID="..." \
  --dart-define=PARSE_CLIENT_KEY="..."
```

No GitHub Actions, cadastrar `PARSE_APPLICATION_ID` e `PARSE_CLIENT_KEY` em **Settings > Secrets and variables > Actions**.
