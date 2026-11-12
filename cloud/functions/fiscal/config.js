'use strict';
const { check, documentId } = require('./domain');
function readConfig(env = process.env) {
  let config;
  try { config = JSON.parse(env.FISCAL_CONFIG_JSON || '{}'); } catch { throw new Error('FISCAL_CONFIG_JSON inválido.'); }
  const missing = [];
  const requireSetting = (valid, label) => { if (!valid) missing.push(label); };
  requireSetting(config.enabled === true, 'Ativação da emissão fiscal');
  requireSetting(['homologacao', 'producao'].includes(config.environment), 'Ambiente fiscal');
  requireSetting(['national', 'municipal'].includes(config.mode), 'Padrão nacional ou municipal');
  requireSetting(config.namespace && /^[a-zA-Z0-9]+$/.test(config.namespace), 'Identificador permanente desta instalação');
  requireSetting(config.issuer?.cnpj?.length === 14 && documentId(config.issuer.cnpj), 'CNPJ válido da empresa');
  requireSetting(config.issuer?.legalName, 'Razão social');
  requireSetting(/^\d{7}$/.test(config.issuer?.municipalityCode || ''), 'Município IBGE da empresa');
  if (config.mode === 'municipal') requireSetting(config.issuer?.municipalRegistration, 'Inscrição municipal');
  if (config.mode === 'national') {
    requireSetting(Number.isInteger(config.series) && config.series >= 1 && config.series <= 49999, 'Série DPS exclusiva desta integração');
    requireSetting(Number.isSafeInteger(config.lastDpsNumber) && config.lastDpsNumber >= 0, 'Último número DPS da série');
  }
  const profiles = Array.isArray(config.profiles) ? config.profiles : [];
  requireSetting(profiles.length > 0, 'Enquadramentos fiscais aprovados');
  requireSetting(new Set(profiles.map(p => p.id)).size === profiles.length, 'Identificadores fiscais únicos');
  for (const p of profiles) {
    requireSetting(p.id && p.label && Array.isArray(p.serviceTypes) && p.serviceTypes.length, 'Nome e tipos de serviço do enquadramento');
    const f = p.fields || {};
    if (config.mode === 'national') {
      requireSetting(/^\d{6}$/.test(f.codigo_tributacao_nacional_iss || '') && f.codigo_opcao_simples_nacional != null && f.regime_especial_tributacao != null && f.tributacao_iss != null && f.tipo_retencao_iss != null, `Tributação nacional: ${p.label || p.id}`);
    } else {
      requireSetting(f.natureza_operacao && typeof f.optante_simples_nacional === 'boolean' && f.servico?.item_lista_servico && typeof f.servico?.iss_retido === 'boolean', `Tributação municipal: ${p.label || p.id}`);
    }
  }
  const tokenName = config.environment === 'producao' ? 'FOCUS_NFE_TOKEN_PRODUCAO' : 'FOCUS_NFE_TOKEN_HOMOLOGACAO';
  requireSetting(env[tokenName], 'Credencial do provedor fiscal no servidor');
  requireSetting(env.FISCAL_SCHEMA_READY === 'true', 'Instalação das classes e índices fiscais');
  return { ...config, profiles, missing, ready: missing.length === 0 };
}
function requireReady(config) { check(config.ready, 'Emissão indisponível: ' + (config.missing || []).join('; ') + '.'); }
module.exports = { readConfig, requireReady };
