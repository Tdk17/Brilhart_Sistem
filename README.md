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
- NFS-e no MVP: emissão por serviço, consulta, reenvio, cancelamento e XML/PDF via provedor fiscal
- Documentos de fechamento e anexos
- Central de documentos
- Fluxo de contato/compartilhamento por WhatsApp
- Configurações da empresa
- PWA instalável e responsiva

## Identidade visual

Tema corporativo **azul-marinho, cinza e azul**, com navegação lateral, barra de trabalho, indicadores e tabelas em desktop. A logo oficial da Brilhart está em `assets/images/brilhart_logo.png` e também foi preparada para favicon e ícones da PWA.

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

## Emissão fiscal no MVP

A NFS-e faz parte do MVP. A central fica em `/notas-fiscais` e também pode ser aberta por um serviço na Produção. O conector inicial utiliza a API Focus NFe, com padrões nacional e municipal configuráveis no servidor.

O código fiscal e a documentação de implantação estão em `cloud/` e [docs/FISCAL_MODULE.md](docs/FISCAL_MODULE.md). Publicar o frontend não instala o Cloud Code: é necessário acrescentar as funções ao Back4App, configurar classes/roles/índices, dados fiscais e credenciais, e homologar com a empresa. Nenhuma emissão real é simulada e o envio fica indisponível até a configuração.

Não incluir certificado, token do emissor ou Parse Master Key no build Flutter. Verificação automatizada: `npm test --prefix cloud`, `flutter analyze --no-fatal-infos`, `flutter test` e build web pelo workflow `validate.yml`.

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

## Desktop Windows (novo)

O projeto continua disponível como Web/PWA e passa a ter um processo de compilação Windows.
O workflow `.github/workflows/desktop-windows.yml` pode ser executado manualmente para produzir o pacote portátil `Brilhart-Windows.zip` como artefato do GitHub Actions. Tags `v*` também publicam esse pacote no GitHub Releases.

O runner Windows é gerado com `flutter create --platforms=windows .` durante o workflow; o pacote inclui o executável e suas dependências e não é um instalador MSI/EXE de instalação.

1. Configure `PARSE_APPLICATION_ID` e `PARSE_CLIENT_KEY` nos Secrets do Actions. Nunca use a Master Key do Parse no cliente.
2. Execute o workflow Windows ou publique uma tag de versão (por exemplo, `v1.0.0`) depois de integrar a branch.
3. Verifique o pacote publicado antes de divulgar o download. Em `Settings > Secrets and variables > Actions > Variables`, configure `DESKTOP_DOWNLOAD_URL` com a URL HTTPS efetiva do pacote publicado, por exemplo `https://github.com/Tdk17/Brilhart_Sistem/releases/latest/download/Brilhart-Windows.zip`.
4. Faça um novo deploy Web. Sem `DESKTOP_DOWNLOAD_URL`, o botão de download na tela de login permanece desativado para não apontar para um arquivo inexistente.

**Limite atual:** o workflow prepara um pacote portátil para Windows, não instala automaticamente nem comprova compatibilidade offline. O acesso aos dados ainda exige conexão com o Parse/Back4App; funcionalidade realmente offline/sincronização requer armazenamento local e fila de operações.
