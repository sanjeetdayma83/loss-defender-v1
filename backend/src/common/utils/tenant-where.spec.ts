import { tenantWhere } from "./tenant-where";

describe("tenantWhere", () => {
  it("throws when companyId empty", () => {
    expect(() => tenantWhere("", { id: "x" })).toThrow(/companyId/);
  });

  it("throws when companyId whitespace", () => {
    expect(() => tenantWhere("   ", {})).toThrow(/companyId/);
  });

  it("merges companyId into where", () => {
    const w = tenantWhere("co-1", { id: "ord-1" });
    expect(w).toEqual({ companyId: "co-1", id: "ord-1" });
  });

  it("does not trust client companyId in extra filter", () => {
    const w = tenantWhere("co-own", { companyId: "co-attacker", id: "x" } as any);
    expect(w.companyId).toBe("co-own");
  });

  it("supports status filter", () => {
    const w = tenantWhere("co-1", { status: "active" });
    expect(w).toMatchObject({ companyId: "co-1", status: "active" });
  });
});