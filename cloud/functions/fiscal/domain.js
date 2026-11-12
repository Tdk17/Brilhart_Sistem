'use strict';
const { createHash } = require('node:crypto');

class FiscalError extends Error {}
const check = (condition, message) => { if (!condition) throw new FiscalError(message); };
const clean = (value) => String(value ?? '').trim();
function documentId(value) {
  const doc = clean(value).toUpperCase().replace(/[.\/\s-]/g, '');
  if (/^(\d)\1+$/.test(doc)) return '';
  if (/^\d{11}$/.test(doc)) {
    for (let length = 9; length < 11; length++) {
      const sum = [...doc.slice(0, length)].reduce((s, c, i) => s + Number(c) * (length + 1 - i), 0);
      const digit = (sum * 10) % 11 % 10;
      if (digit !== Number(doc[length])) return '';
    }
    return doc;
  }
  if (!/^[A-Z0-9]{12}\d{2}$/.test(doc)) return '';
  for (let length = 12; length < 14; length++) {
    const sum = [...doc.slice(0, length)].reverse().reduce((s, c, i) => s + (c.charCodeAt(0) - 48) * (2 + i % 8), 0);
    const rest = sum % 11;
    if ((rest < 2 ? 0 : 11 - rest) !== Number(doc[length])) return '';
  }
  return doc;
}
function text(value, label, max = 150) {
  const result = clean(value);
  check(result.length > 0 && result.length <= max, `${label}: informe de 1 a ${max} caracteres.`);
  return result;
}
function recipient(input = {}) {
  const document = documentId(input.document);
  check(document, 'CPF/CNPJ do cliente inválido.');
  const result = { document, name: text(input.name, 'Nome/razão social', 115),
    street: text(input.street, 'Logradouro', 125), number: text(input.number, 'Número', 10),
    district: text(input.district, 'Bairro', 60), municipalityCode: clean(input.municipalityCode),
    state: clean(input.state).toUpperCase(), postalCode: clean(input.postalCode).replace(/[.\s-]/g, '') };
  check(/^\d{7}$/.test(result.municipalityCode), 'Código IBGE do cliente deve ter 7 dígitos.');
  check('AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO'.split(' ').includes(result.state), 'UF inválida.');
  check(/^\d{8}$/.test(result.postalCode), 'CEP deve ter 8 dígitos.');
  if (clean(input.email)) {
    check(clean(input.email).length <= 80 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email), 'E-mail inválido.');
    result.email = clean(input.email);
  }
  return result;
}
function hash(value) { return createHash('sha256').update(JSON.stringify(value)).digest('hex'); }
function reference(config, serviceId) {
  return 'brilhart' + hash([config.namespace, config.issuer.cnpj, config.environment, serviceId]).slice(0, 40);
}
function prepare(config, service, client, input, now = new Date()) {
  check(service.status === 'Concluído', 'Conclua o serviço antes de emitir a NFS-e.');
  check(service.clientId === client.id, 'Cliente do serviço não encontrado.');
  const value = service.value;
  check(typeof value === 'number' && Number.isFinite(value) && value > 0 && value < 1e10 && Math.abs(value * 100 - Math.round(value * 100)) < 0.0001, 'Valor do serviço inválido; corrija o cadastro.');
  const description = text(service.description, 'Descrição do serviço', 1000);
  const competence = clean(input.competence);
  check(/^\d{4}-\d{2}-\d{2}$/.test(competence) && !Number.isNaN(Date.parse(competence)) && new Date(competence).toISOString().startsWith(competence), 'Data de competência inválida.');
  check(competence <= now.toISOString().slice(0, 10), 'Competência não pode ser futura.');
  const profile = config.profiles.find(p => p.id === input.profileId);
  check(profile && profile.serviceTypes.includes(service.serviceType), 'Selecione um enquadramento fiscal aprovado para este tipo de serviço.');
  const customer = recipient(input.recipient);
  const serviceMunicipality = clean(input.serviceMunicipality);
  check(/^\d{7}$/.test(serviceMunicipality), 'Código IBGE da prestação deve ter 7 dígitos.');
  const snapshot = { serviceId: service.id, clientId: client.id, clientName: client.name,
    value, description, competence, recipient: customer, serviceMunicipality,
    profileId: profile.id, profileLabel: profile.label, taxFields: profile.fields,
    mode: config.mode, environment: config.environment, issuer: config.issuer, series: config.series };
  return { ...snapshot, previewHash: hash(snapshot) };
}
function buildPayload(snapshot, issuedAt, dpsNumber) {
  const s = snapshot, r = s.recipient, issuer = s.issuer;
  const tax = JSON.parse(JSON.stringify(s.taxFields));
  if (s.mode === 'national') {
    return { ...tax, data_emissao: issuedAt, data_competencia: s.competence,
      serie_dps: s.series, numero_dps: dpsNumber, emitente_dps: '1',
      codigo_municipio_emissora: issuer.municipalityCode, cnpj_prestador: issuer.cnpj,
      ...(issuer.municipalRegistration ? { inscricao_municipal_prestador: issuer.municipalRegistration } : {}),
      codigo_municipio_prestacao: s.serviceMunicipality,
      ...(r.document.length === 11 ? { cpf_tomador: r.document } : { cnpj_tomador: r.document }),
      razao_social_tomador: r.name, codigo_municipio_tomador: r.municipalityCode,
      cep_tomador: r.postalCode, logradouro_tomador: r.street, numero_tomador: r.number,
      bairro_tomador: r.district, ...(r.email ? { email_tomador: r.email } : {}),
      descricao_servico: s.description, valor_servico: s.value };
  }
  return { ...tax, data_emissao: issuedAt,
    prestador: { cnpj: issuer.cnpj, inscricao_municipal: issuer.municipalRegistration, codigo_municipio: issuer.municipalityCode },
    tomador: { ...(r.document.length === 11 ? { cpf: r.document } : { cnpj: r.document }),
      razao_social: r.name, ...(r.email ? { email: r.email } : {}),
      endereco: { logradouro: r.street, numero: r.number, bairro: r.district,
        codigo_municipio: r.municipalityCode, uf: r.state, cep: r.postalCode } },
    servico: { ...tax.servico, valor_servicos: s.value, discriminacao: s.description, codigo_municipio: s.serviceMunicipality } };
}
function normalizeResponse(body, previous = 'processing') {
  const statuses = { processando_autorizacao: 'processing', autorizado: 'authorized',
    cancelado: 'cancelled', erro_autorizacao: 'rejected', negado: 'denied',
    processando_cancelamento: 'cancelling', erro_cancelamento: 'authorized' };
  // An unrecognized or missing status is never proof of authorization or rejection.
  const status = statuses[body?.status] || (['authorized', 'cancelled', 'denied'].includes(previous) ? previous : 'unknown');
  return { status, providerStatus: clean(body?.status), number: clean(body?.numero),
    verificationCode: clean(body?.codigo_verificacao), protocol: clean(body?.protocolo),
    xmlPath: clean(body?.caminho_xml_nota_fiscal), pdfPath: clean(body?.url_danfse || body?.url),
    message: (Array.isArray(body?.erros) ? body.erros.map(e => [e.codigo, e.mensagem, e.correcao].filter(Boolean).join(' — ')).join('\n') : clean(body?.mensagem)).slice(0, 3000) };
}
module.exports = { FiscalError, check, clean, text, documentId, recipient, hash, reference, prepare, buildPayload, normalizeResponse };
