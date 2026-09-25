# BrilhArte Sistem

Sistema interno **Web/PWA** da BrilhArte Laqueamentos, construído em Flutter Web seguindo o padrão dos projetos CormeX: `get_it`, `go_router`, `signals`, integração real com backend via Parse/Back4App e sem dados mockados.

## Módulos

- Login sem cadastro público e sessão persistente
- Dashboard operacional e comercial
- Clientes
- Solicitações de orçamento originadas pelo site
- Orçamentos oficiais com PDF A4
- Conversão de orçamento em serviço
- Produção/serviços e controle de atrasos
- Faturamento
- Contratos
- Notas/documentos de fechamento
- Central de documentos
- Compartilhamento por WhatsApp
- Configurações da empresa
- Formulário público de solicitação de orçamento
- PWA instalável e responsiva

## Tema

Identidade visual preta, prata e dourada. A logo oficial da BrilhArte está em `assets/images/brilhart_logo.png` e é usada no login, navegação, PWA e documentos.

## Backend

O frontend não contém mocks. Ele espera as Cloud Functions descritas em `docs/API_CONTRACT.md`.

Variáveis de build:

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

O workflow `.github/workflows/deploy-pages.yml` publica automaticamente a branch `main` em GitHub Pages com base href `/Brilhart_Sistem/`.
