// Copy to config.ts (gitignored) and fill in. The secret ships inside the
// .pbiviz artifact; it gates casual access to an internal, tenant-gated report.
export const BOARD_CONFIG = {
    baseUrl: "https://michelman-writeback.michelman-bi.workers.dev",
    secret: "<worker SHARED_SECRET>",
};
