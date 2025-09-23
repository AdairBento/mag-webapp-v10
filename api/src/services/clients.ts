export interface Client {
  id: string;
  name: string;
}

export async function listClients(): Promise<Client[]> {
  // em produção: DB/external API; aqui um default simples
  return [{ id: "1", name: "Acme Corp" }];
}
