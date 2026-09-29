import { describe, expect, it } from "vitest";
import { fail, ok } from "./action-result";

describe("action result", () => {
  it("wraps success", () => expect(ok("Xong")).toEqual({ ok: true, message: "Xong", data: undefined }));
  it("maps error codes to Vietnamese", () => {
    expect(fail({ message: "invalid_state" })).toEqual({
      ok: false,
      error: "Trạng thái hiện tại không cho phép thao tác này.",
    });
    expect(fail(new Error("kaboom"))).toMatchObject({ ok: false });
  });
});
