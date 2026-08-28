export function tenantWhere(companyId: string, extra: Record<string, unknown> = {}) {
  if (!companyId || typeof companyId !== "string") {
    throw new Error("tenantWhere: companyId is required and must be a string");
  }
  return { companyId, ...extra };
}
