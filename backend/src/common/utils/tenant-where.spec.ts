import { tenantWhere } from "./tenant-where";

describe("tenantWhere", () => {
  it("throws when companyId empty", () => {
    expect(() => tenantWhere("", { id: "x" })).toThrow(/companyId/);
  });
  it("merges companyId into where", () => {
    const w = tenantWhere("co-1", { id: "ord-1" });
    expect(w).toEqual({ companyId: "co-1", id: "ord-1" });
  });
});
