import { SetMetadata } from "@nestjs/common";

export type AppRole =
  | "super_admin"
  | "company_admin"
  | "warehouse_manager"
  | "supervisor"
  | "packing_operator"
  | "qc_operator"
  | "claims_executive"
  | "marketplace_manager"
  | "viewer"
  | "auditor";

export const ROLES_KEY = "roles";
export const Roles = (...roles: AppRole[]) => SetMetadata(ROLES_KEY, roles);