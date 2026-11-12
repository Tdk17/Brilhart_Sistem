'use strict';
const { FiscalError, check } = require('./domain');
const BASES = { homologacao: 'https://homologacao.focusnfe.com.br', producao: 'https://api.focusnfe.com.br' };
class ProviderError extends Error {
  constructor(message, status) { super(message); this.status = status; }
}
class FocusProvider {
  constructor(env = process.env, fetcher = global.fetch) { this.env = env; this.fetcher = fetcher; }
  connection(invoice) {
    const base = BASES[invoice.environment];
    check(base && ['national', 'municipal'].includes(invoice.mode), 'Ambiente fiscal inválido.');
    const token = this.env[invoice.environment === 'producao' ? 'FOCUS_NFE_TOKEN_PRODUCAO' : 'FOCUS_NFE_TOKEN_HOMOLOGACAO'];
    check(token, 'Credencial fiscal deste ambiente não configurada no servidor.');
    return { base, authorization: 'Basic ' + Buffer.from(token + ':').toString('base64'),
      endpoint: '/v2/' + (invoice.mode === 'national' ? 'nfsen' : 'nfse') };
  }
  async request(invoice, method, suffix, body) {
    const c = this.connection(invoice);
    let response;
    try {
      response = await this.fetcher(c.base + c.endpoint + suffix, { method, redirect: 'error',
        headers: { Authorization: c.authorization, 'Content-Type': 'application/json', Accept: 'application/json' },
        ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(12000) });
    } catch { throw new ProviderError('Sem confirmação do provedor. Consulte a situação antes de tentar novamente.', 0); }
    let data;
    try { data = await response.json(); } catch { throw new ProviderError('Resposta fiscal inválida. Consulte a situação da nota.', response.status >= 500 ? response.status : 0); }
    if (!response.ok) throw new ProviderError(String(data.mensagem || 'Falha na comunicação com o provedor fiscal.').slice(0, 1000), response.status);
    return data;
  }
  send(invoice, payload) { return this.request(invoice, 'POST', '?ref=' + encodeURIComponent(invoice.reference), payload); }
  consult(invoice) { return this.request(invoice, 'GET', '/' + encodeURIComponent(invoice.reference)); }
  cancel(invoice, reason) { return this.request(invoice, 'DELETE', '/' + encodeURIComponent(invoice.reference), { justificativa: reason }); }
  async download(invoice, kind) {
    const c = this.connection(invoice);
    const path = kind === 'xml' ? invoice.xmlPath : invoice.pdfPath;
    check(path, 'O provedor ainda não disponibilizou este arquivo.');
    const allowed = new Set([new URL(c.base).hostname, ...String(this.env.FISCAL_DOCUMENT_HOSTS || '').split(',').map(s => s.trim()).filter(Boolean)]);
    let url = new URL(path, c.base);
    for (let attempt = 0; attempt < 4; attempt++) {
      check(url.protocol === 'https:' && !url.username && !url.password && (!url.port || url.port === '443') && allowed.has(url.hostname), 'Endereço do documento requer liberação do administrador fiscal.');
      const response = await this.fetcher(url, { redirect: 'manual', signal: AbortSignal.timeout(12000),
        headers: url.origin === c.base ? { Authorization: c.authorization } : {} });
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        check(response.headers.get('location'), 'Redirecionamento fiscal inválido.');
        url = new URL(response.headers.get('location'), url); continue;
      }
      check(response.ok, 'Não foi possível baixar o documento fiscal.');
      const chunks = []; let size = 0;
      for await (const chunk of response.body) {
        size += chunk.length; check(size <= 8 * 1024 * 1024, 'Arquivo fiscal excede o limite de 8 MB.'); chunks.push(chunk);
      }
      const bytes = Buffer.concat(chunks);
      const prefix = bytes.toString('utf8', 0, 200).trimStart();
      check(kind === 'pdf' ? prefix.startsWith('%PDF-') : /^(<\?xml|<(?:\w+:)?(?:CompNfse|Nfse|NFSe|nfse|ConsultarNfse|EnviarLoteRps))/.test(prefix), 'O provedor retornou um formato diferente do arquivo solicitado.');
      return { base64: bytes.toString('base64'), fileName: `nfse-${invoice.environment}-${invoice.number || invoice.reference}.${kind}`, contentType: kind === 'pdf' ? 'application/pdf' : 'application/xml' };
    }
    throw new FiscalError('Muitos redirecionamentos ao baixar o documento.');
  }
}
module.exports = { FocusProvider, ProviderError };
