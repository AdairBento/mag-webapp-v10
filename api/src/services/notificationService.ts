
import Mustache from 'mustache';
import axios from 'axios';
import { prisma } from '../index';

type Vars = Record<string, string | number | boolean>;
export function render(content: string, variables: Vars) { return Mustache.render(content, variables || {}); }

export async function queueAndSendWhatsApp(params: { tenantId: string; clientId?: string; contractId?: string; to: string; content: string; templateId?: string; }) {
  const msg = await prisma.notificationMessage.create({ data: { tenantId: params.tenantId, clientId: params.clientId, contractId: params.contractId, channel: 'whatsapp', to: params.to, content: params.content, templateId: params.templateId ?? null, status: 'queued' } });
  try {
    const settings = await prisma.tenantSettings.findUnique({ where: { tenantId: params.tenantId } });
    if (!settings?.whatsappAccessToken || !settings?.whatsappPhoneNumberId) throw new Error('WhatsApp não configurado');
    const url = `https://graph.facebook.com/v19.0/${settings.whatsappPhoneNumberId}/messages`;
    await axios.post(url, { messaging_product: 'whatsapp', to: params.to, type: 'text', text: { body: params.content } }, { headers: { Authorization: `Bearer ${settings.whatsappAccessToken}` } });
    await prisma.notificationMessage.update({ where: { id: msg.id }, data: { status: 'sent', sentAt: new Date() } });
  } catch (e: any) {
    await prisma.notificationMessage.update({ where: { id: msg.id }, data: { status: 'failed', error: String(e?.message || e) } });
    throw e;
  }
}
