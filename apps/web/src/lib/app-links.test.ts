import { describe, expect, it } from "vitest";
import { buildAppleAssociation, buildAssetLinks } from "./app-links";

describe("app links", () => {
  it("returns empty documents when env is unset", () => {
    expect(buildAssetLinks({} as NodeJS.ProcessEnv)).toEqual([]);
    expect(buildAppleAssociation({} as NodeJS.ProcessEnv).applinks.details).toEqual([]);
  });

  it("builds android and apple documents from env", () => {
    const env = {
      ANDROID_PACKAGE_NAME: "vn.x.y",
      ANDROID_SHA256_FINGERPRINTS: "AA:BB, CC:DD",
      APPLE_TEAM_ID: "TEAM123",
      IOS_BUNDLE_ID: "vn.x.y",
    } as unknown as NodeJS.ProcessEnv;
    expect(buildAssetLinks(env)[0].target.sha256_cert_fingerprints).toEqual(["AA:BB", "CC:DD"]);
    expect(buildAppleAssociation(env).applinks.details[0].appIDs).toEqual(["TEAM123.vn.x.y"]);
  });
});
