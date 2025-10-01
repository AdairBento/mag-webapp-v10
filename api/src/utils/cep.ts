/* global fetch */
export async function lookupCep(rawCep: string) {
  const only = (rawCep || "").replace(/\D/g, "");
  if (only.length !== 8) throw new Error("CEP inválido");
  const r = await fetch(`https://viacep.com.br/ws/${only}/json/`);
  if (!r.ok) throw new Error("Falha ao consultar CEP");
  const data = await r.json();
  if (data?.erro) throw new Error("CEP não encontrado");
  return {
    cep: only,
    street: data.logradouro || null,
    district: data.bairro || null,
    city: data.localidade || null,
    state: data.uf || null,
  };
}
