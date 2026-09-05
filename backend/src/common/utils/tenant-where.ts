export function tenantWhere(
  companyId: string,
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  if (!companyId || typeof companyId !== "string" || !companyId.trim()) {
    throw new Error("tenantWhere: companyId is required and must be a non-empty string");
  }
  const { companyId: _ignored, ...rest } = extra;
  return { ...rest, companyId };
}