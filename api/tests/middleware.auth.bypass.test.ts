// DESCOMENTE 'describe.skip' -> 'describe' se seu middleware libera OPTIONS sem auth
import { describe, it, expect } from "vitest";
import request from "supertest";
import * as AppMod from "../src/http/app";

const make =
  (AppMod as any).createApp ?? ((AppMod as any).default && (AppMod as any).default.createApp);

const PROTECTED = "/clients";

if (typeof make !== "function") {
  describe.skip("auth middleware - bypass (createApp indisponível)", () => {
    it("skipped", () => {});
  });
} else {
  const app = make();
  describe.skip("auth middleware - bypass (se aplicável)", () => {
    it("permite OPTIONS sem Authorization (preflight)", async () => {
      const res = await request(app).options(PROTECTED);
      expect([200, 204]).toContain(res.status);
    });
  });
}
