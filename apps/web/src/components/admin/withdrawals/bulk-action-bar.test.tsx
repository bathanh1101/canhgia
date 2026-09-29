import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/admin/require-admin", () => ({ requireAdmin: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import { ResultsList } from "./bulk-action-bar";

describe("ResultsList", () => {
  it("shows ok and the mapped admin error per row", () => {
    render(
      <ResultsList
        labels={new Map([["a", "a@x · 1đ"], ["b", "b@x · 2đ"], ["c", "c@x · 3đ"]])}
        results={[
          { id: "a", ok: true },
          { id: "b", ok: false, error: "not_claimer" },
          { id: "c", ok: false, error: "bank_unverified" },
        ]}
      />,
    );
    expect(screen.getByText(/a@x · 1đ: Thành công/)).toBeInTheDocument();
    expect(screen.getByText(/b@x · 2đ: Yêu cầu này đang được quản trị viên khác xử lý/)).toBeInTheDocument();
    expect(screen.getByText(/c@x · 3đ: Tài khoản ngân hàng chưa được xác minh/)).toBeInTheDocument();
  });
});
