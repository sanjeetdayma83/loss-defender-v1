import { SetMetadata } from "@nestjs/common";

export const PLAN_LIMIT_KEY = "plan_limit";

export type PlanLimitResource =
  | "users"
  | "warehouses"
  | "storage";

export const EnforcePlanLimit = (resource: PlanLimitResource) =>
  SetMetadata(PLAN_LIMIT_KEY, resource);