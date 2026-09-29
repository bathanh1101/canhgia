// Universal/App Links documents, keyed on env so no domain or fingerprint is hardcoded.
// Values are filled per environment (phase 12); missing values yield empty targets.

const list = (v: string | undefined) =>
  (v ?? "").split(",").map((s) => s.trim()).filter(Boolean);

export function buildAssetLinks(env: NodeJS.ProcessEnv = process.env) {
  const fingerprints = list(env.ANDROID_SHA256_FINGERPRINTS);
  const pkg = env.ANDROID_PACKAGE_NAME;
  if (!pkg || fingerprints.length === 0) return [];
  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: pkg,
        sha256_cert_fingerprints: fingerprints,
      },
    },
  ];
}

export function buildAppleAssociation(env: NodeJS.ProcessEnv = process.env) {
  const team = env.APPLE_TEAM_ID;
  const bundle = env.IOS_BUNDLE_ID;
  const details =
    team && bundle
      ? [{ appIDs: [`${team}.${bundle}`], components: [{ "/": "/r/*" }] }]
      : [];
  return { applinks: { details } };
}
