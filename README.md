# Brilhart Sistem

Sistema interno **Web/PWA** da Brilhart Laqueamentos, construído em Flutter Web seguindo o padrão dos projetos CormeX: `get_it`, `go_router`, `signals`, integração real com Parse/Back4App e sem dados mockados.

## Acesso Web

Quando o workflow de deploy estiver concluído, o sistema fica em:

`https://tdk17.github.io/Brilhart_Sistem/`

Solicitação pública de orçamento:

`https://tdk17.github.io/Brilhart_Sistem/#/solicitar-orcamento`

## Módulos

- Login interno por e-mail/senha, sem cadastro público
- Sessão persistente e rotas protegidas
- Dashboard operacional e comercial
- Clientes: cadastro, edição, busca, exclusão conforme regra e histórico
- Solicitações de orçamento originadas pelo site, com fotos e origem preservada
- Conversão solicitação -> cliente/orçamento
- Orçamentos oficiais e contrato de PDF A4
- Conversão orçamento aprovado -> serviço
- Produção/serviços, prazos, atrasos e conclusão
- Faturamento e métricas por origem
- Contratos
- Notas/documentos de fechamento
- Central de documentos
- Fluxo de contato/compartilhamento por WhatsApp
- Configurações da empresa
- PWA instalável e responsiva

## Identidade visual

Tema corporativo **preto, prata e dourado**. A logo oficial da Brilhart está em `assets/images/brilhart_logo.png` e também foi preparada para favicon e ícones da PWA.

## Arquitetura

```text
lib/
  core/
    router/
    services/
    theme/
  features/
    auth/
    billing/
    dashboard/
    public/
    settings/
    shared/
    shell/
web/
  icons/
docs/
.github/workflows/
```

## Backend / Back4App

O frontend não usa mocks. A autenticação usa a sessão nativa do Parse/Back4App. As Cloud Functions e classes esperadas para os módulos operacionais estão documentadas em:

`docs/API_CONTRACT.md`

Principais modelos: `_User`, `Client`, `QuoteRequest`, `Quote`, `Service`, `Contract`, `ClosingDocument`, `ShareLog`, `CompanySettings` e `AuditLog`.

## Variáveis de build

```bash
--dart-define=APP_ENV=production
--dart-define=PARSE_SERVER_URL=https://parseapi.back4app.com
--dart-define=PARSE_APPLICATION_ID=...
--dart-define=PARSE_CLIENT_KEY=...
```

## Executar localmente

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=APP_ENV=qa \
  --dart-define=PARSE_APPLICATION_ID=... \
  --dart-define=PARSE_CLIENT_KEY=...
```

## GitHub Pages

O workflow `.github/workflows/deploy-pages.yml` executa:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter build web --release --base-href "/Brilhart_Sistem/"`
4. cria fallback `404.html` para a SPA
5. publica em GitHub Pages

No repositório, cadastre em **Settings > Secrets and variables > Actions**:

- `PARSE_APPLICATION_ID`
- `PARSE_CLIENT_KEY`

E mantenha o GitHub Pages configurado para **GitHub Actions** como fonte de publicação.

## Regra de projeto

Este é um sistema novo e independente. O aplicativo Brilhart existente não deve ser alterado por este projeto.
