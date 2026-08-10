// Michelman Writeback Worker — single-file router over one D1 database.
// Serves two Power BI custom visuals (Revision Log Editor + Order Line
// Comments). Ported from the Terrasmart DeliveryReliability worker; see
// writeback/ARCHITECTURE.md for the source-of-truth spec.
//
// Auth: `x-secret` on every route except /health. Identity is the self-
// asserted `x-actor-email` header (internal, tenant-gated report threat model);
// roles resolve server-side against the `people` table.

interface Env {
  DB: D1Database;
  SHARED_SECRET: string;
  ALLOWED_ORIGIN?: string;
}

interface RevisionOverrideRow {
  revision_key: string;
  order_line_id: string | null;
  change_date: string | null;
  change_time: string | null;
  revision_reason_override: string | null;
  note: string | null;
  exclude_flag: number;
  created_at: string;
  updated_at: string;
}

interface CommentRow {
  id: number;
  order_line_id: string;
  body: string;
  actor_email: string | null;
  created_at: string;
  updated_at: string | null;
  deleted_at: string | null;
}

interface CommentHistoryRow {
  history_id: number;
  order_line_id: string;
  comment_id: number | null;
  actor_email: string | null;
  changed_at: string;
  action: string;
  old_value: string | null;
  new_value: string | null;
}

// Page-level discussion thread (Order Line Comments' sibling with no order grain).
interface BoardCommentRow {
  id: number;
  board_key: string;
  body: string;
  /** 'Americas' | 'EMEA' | 'Asia', or null for a post that concerns every region. */
  region: string | null;
  actor_email: string | null;
  created_at: string;
  updated_at: string | null;
  deleted_at: string | null;
}

interface PersonRow {
  person_key: string;
  person_name: string;
  display_name: string | null;
  email: string | null;
  role: string | null;
  active: number;
  created_at: string;
  updated_at: string;
}

interface HistoryRow {
  history_id: number;
  revision_key: string;
  actor_email: string | null;
  changed_at: string;
  field: string;
  old_value: string | null;
  new_value: string | null;
}

interface ReasonCodeRow {
  code_id: number;
  code: string;
  label: string | null;
  sort_order: number;
  active: number;
  created_at: string;
  updated_at: string;
}

interface ReasonDimRow {
  code: string;
  description: string | null;
  long_description: string | null;
  exemption_criteria: string | null;
  otif: number;
  category: string | null;
  // Extra columns preserved verbatim from the SharePoint workbook so no source
  // data is lost (sheet "Reason Codes 20181017"). The three X-mark milestone
  // flags are 0/1; the rest are free text.
  review_530: number;
  review_540: number;
  typical_hit: number;
  old_classification: string | null;
  usage_examples: string | null;
  region_note: string | null;
  active: number;
  sort_order: number;
  updated_by: string | null;
  created_at: string;
  updated_at: string;
}

type Role = "admin" | "editor" | "restricted";

// Fields diffed into override_history on each revision-override PUT.
const HISTORY_FIELDS = ["revisionReason", "note", "excludeFlag"] as const;
type HistoryField = (typeof HISTORY_FIELDS)[number];

// Fields diffed into reason_dim_history on each PUT /reason-dim.
const REASON_DIM_HISTORY_FIELDS = [
  "description",
  "longDescription",
  "exemptionCriteria",
  "otif",
  "category",
  "review530",
  "review540",
  "typicalHit",
  "oldClassification",
  "usageExamples",
  "regionNote",
  "active",
  "sortOrder",
] as const;
type ReasonDimHistoryField = (typeof REASON_DIM_HISTORY_FIELDS)[number];

function normalizeRole(x: unknown): Role | null | undefined {
  if (x === undefined) return undefined;
  if (x === null) return null;
  if (typeof x !== "string") return undefined;
  const v = x.trim().toLowerCase();
  if (v === "") return null;
  if (v === "admin" || v === "editor" || v === "restricted") return v;
  return undefined;
}

function normalizeEmail(x: unknown): string | null | undefined {
  if (x === undefined) return undefined;
  if (x === null) return null;
  if (typeof x !== "string") return undefined;
  const v = x.trim().toLowerCase();
  return v === "" ? null : v;
}

function nullableString(x: unknown): string | null | undefined {
  if (x === undefined) return undefined;
  if (x === null) return null;
  if (typeof x === "string") {
    const t = x.trim();
    return t === "" ? null : t;
  }
  return undefined;
}

/**
 * Replaces a person's company list wholesale. Accepts an array, or the comma/space
 * separated string the People panel's single input produces. `undefined` means
 * "not supplied — leave alone"; an empty array means "clear them" (= read-only).
 */
async function setPersonCompanies(env: Env, key: string, raw: unknown): Promise<string[] | undefined> {
  if (raw === undefined) return undefined;
  const parts = Array.isArray(raw)
    ? raw
    : typeof raw === "string"
      ? raw.split(/[,;\s]+/)
      : [];
  const companies = Array.from(
    new Set(parts.map(normalizeCompany).filter((c): c is string => !!c))
  ).sort();
  await env.DB.prepare(`DELETE FROM people_companies WHERE person_key = ?`).bind(key).run();
  for (const c of companies) {
    await env.DB.prepare(
      `INSERT OR IGNORE INTO people_companies (person_key, company) VALUES (?, ?)`
    ).bind(key, c).run();
  }
  return companies;
}

function boolFlag(x: unknown): 0 | 1 | undefined {
  if (x === undefined) return undefined;
  return x ? 1 : 0;
}

function personKey(x: string): string {
  return x.trim().toUpperCase();
}

function actorEmailOf(req: Request): string | null {
  return req.headers.get("x-actor-email")?.trim().toLowerCase() || null;
}

async function actorRole(req: Request, env: Env): Promise<Role | null> {
  const email = actorEmailOf(req);
  if (!email) return null;
  const row = await env.DB.prepare(
    `SELECT role FROM people WHERE email = ? AND active = 1 LIMIT 1`
  ).bind(email).first<{ role: string | null }>();
  const r = row?.role?.toLowerCase();
  if (r === "admin" || r === "editor" || r === "restricted") return r;
  return null;
}

/**
 * Canonical company code: the 5-char zero-padded JDE order company ('00010').
 * Admins may type 10 / 0010 / 00010 and get the same row. Anything with a non-digit
 * is kept verbatim (trimmed, uppercased) rather than mangled.
 */
function normalizeCompany(x: unknown): string | null {
  const s = nullableString(x);
  if (!s) return null;
  const t = s.trim();
  if (!/^\d+$/.test(t)) return t.toUpperCase();
  return t.replace(/^0+/, "").padStart(5, "0");
}

/** Company owning a row, read off the Order Line ID: "00010,74,CM,4.000" -> "00010". */
function companyOfOrderLineId(orderLineId: string | null | undefined): string | null {
  if (!orderLineId) return null;
  return normalizeCompany(orderLineId.split(",")[0]);
}

interface ActorPermissions {
  email: string | null;
  personKey: string | null;
  isAdmin: boolean;
  companies: string[];
}

/**
 * Resolves what the caller may edit. Per the agreed model the role no longer gates
 * editing — only `admin` still means anything (manage People / reason codes, and edit
 * every company). Everyone else edits exactly the companies listed against their email.
 */
async function actorPermissions(req: Request, env: Env): Promise<ActorPermissions> {
  const email = actorEmailOf(req);
  if (!email) return { email: null, personKey: null, isAdmin: false, companies: [] };
  const person = await env.DB.prepare(
    `SELECT person_key, role FROM people WHERE email = ? AND active = 1 LIMIT 1`
  ).bind(email).first<{ person_key: string; role: string | null }>();
  if (!person) return { email, personKey: null, isAdmin: false, companies: [] };
  const rs = await env.DB.prepare(
    `SELECT company FROM people_companies WHERE person_key = ?`
  ).bind(person.person_key).all<{ company: string }>();
  return {
    email,
    personKey: person.person_key,
    isAdmin: person.role?.toLowerCase() === "admin",
    companies: rs.results.map((r) => r.company),
  };
}

function mayEditCompany(perms: ActorPermissions, company: string | null): boolean {
  if (perms.isAdmin) return true;
  if (!company) return false;
  return perms.companies.includes(company);
}

/** 403 body that tells the visual exactly why, so it can render a useful message. */
function forbidden(perms: ActorPermissions, company: string | null, env: Env): Response {
  const detail = !perms.personKey
    ? "not on the approved editors list"
    : perms.companies.length === 0
      ? "no companies assigned"
      : `not approved for company ${company ?? "(unknown)"}`;
  return err(403, `edit not permitted: ${detail}`, env);
}

async function logComment(
  env: Env,
  orderLineId: string,
  commentId: number | null,
  actorEmail: string | null,
  action: "create" | "edit" | "delete",
  oldValue: string | null,
  newValue: string | null
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO comment_history (order_line_id, comment_id, actor_email, action, old_value, new_value)
     VALUES (?, ?, ?, ?, ?, ?)`
  ).bind(orderLineId, commentId, actorEmail, action, oldValue, newValue).run();
}

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };

function corsHeaders(env: Env): Record<string, string> {
  return {
    "access-control-allow-origin": env.ALLOWED_ORIGIN || "*",
    "access-control-allow-methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    "access-control-allow-headers": "content-type,x-secret,x-actor-email",
    "access-control-max-age": "86400",
  };
}

function json(data: unknown, status = 200, env?: Env): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...JSON_HEADERS, ...(env ? corsHeaders(env) : {}) },
  });
}

function err(status: number, message: string, env?: Env): Response {
  return json({ error: message }, status, env);
}

function authed(req: Request, env: Env): boolean {
  const got = req.headers.get("x-secret");
  return !!got && !!env.SHARED_SECRET && got === env.SHARED_SECRET;
}

function overridePayload(r: RevisionOverrideRow) {
  return {
    revisionKey: r.revision_key,
    orderLineId: r.order_line_id,
    changeDate: r.change_date,
    changeTime: r.change_time,
    revisionReason: r.revision_reason_override,
    note: r.note,
    excludeFlag: !!r.exclude_flag,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function commentPayload(r: CommentRow) {
  return {
    id: r.id,
    orderLineId: r.order_line_id,
    body: r.body,
    actorEmail: r.actor_email,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

function commentHistoryPayload(r: CommentHistoryRow) {
  return {
    historyId: r.history_id,
    orderLineId: r.order_line_id,
    commentId: r.comment_id,
    actorEmail: r.actor_email,
    changedAt: r.changed_at,
    action: r.action,
    oldValue: r.old_value,
    newValue: r.new_value,
  };
}

function boardCommentPayload(r: BoardCommentRow) {
  return {
    id: r.id,
    boardKey: r.board_key,
    body: r.body,
    region: r.region ?? null,
    actorEmail: r.actor_email,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

/**
 * The board's region vocabulary, matching 'Dim Region' in the semantic model.
 * Kept as a closed set so a stray value can't create a fourth bucket the filter never shows.
 */
const BOARD_REGIONS = ["Americas", "EMEA", "Asia"] as const;

/**
 * Returns the canonical region name, or null for "all regions".
 * Accepts any casing, plus the few aliases people actually type. `undefined` means the caller
 * sent something outside the vocabulary and should be rejected rather than silently widened
 * to "all regions" — a typo'd region must not quietly post to everyone.
 */
function normalizeRegion(x: unknown): string | null | undefined {
  const s = nullableString(x);
  if (!s) return null;
  const t = s.trim().toLowerCase();
  if (t === "all" || t === "all regions") return null;
  const alias: Record<string, string> = {
    americas: "Americas", america: "Americas", amer: "Americas", na: "Americas",
    emea: "EMEA", europe: "EMEA", eu: "EMEA",
    asia: "Asia", apac: "Asia", ap: "Asia",
  };
  return alias[t] ?? BOARD_REGIONS.find((r) => r.toLowerCase() === t);
}

function historyPayload(r: HistoryRow) {
  return {
    historyId: r.history_id,
    revisionKey: r.revision_key,
    actorEmail: r.actor_email,
    changedAt: r.changed_at,
    field: r.field,
    oldValue: r.old_value,
    newValue: r.new_value,
  };
}

// One Classification picklist choice. `inUse` is the number of reason_dim rows currently
// carrying it — the dialog needs it to explain why a choice cannot just be deleted.
interface ReasonCategoryRow {
  name: string;
  sort_order: number;
  active: number;
  updated_by: string | null;
  updated_at: string;
  in_use: number;
}

function reasonCategoryPayload(r: ReasonCategoryRow) {
  return {
    name: r.name,
    sortOrder: r.sort_order,
    active: !!r.active,
    updatedBy: r.updated_by,
    updatedAt: r.updated_at,
    inUse: r.in_use,
  };
}

function personPayload(r: PersonRow) {
  return {
    personKey: r.person_key,
    personName: r.person_name,
    displayName: r.display_name ?? r.person_name,
    email: r.email,
    role: normalizeRole(r.role) ?? null,
    active: !!r.active,
    updatedAt: r.updated_at,
  };
}

function reasonCodePayload(r: ReasonCodeRow) {
  return {
    codeId: r.code_id,
    code: r.code,
    label: r.label,
    sortOrder: r.sort_order,
    active: !!r.active,
    updatedAt: r.updated_at,
  };
}

function reasonDimPayload(r: ReasonDimRow) {
  return {
    code: r.code,
    description: r.description,
    longDescription: r.long_description,
    exemptionCriteria: r.exemption_criteria,
    otif: !!r.otif,
    category: r.category,
    review530: !!r.review_530,
    review540: !!r.review_540,
    typicalHit: !!r.typical_hit,
    oldClassification: r.old_classification,
    usageExamples: r.usage_examples,
    regionNote: r.region_note,
    active: !!r.active,
    sortOrder: r.sort_order,
    updatedBy: r.updated_by,
    updatedAt: r.updated_at,
  };
}

// Executive Scorecard section 3 — manually maintained KPIs. Display text plus a
// trend verdict speaking the same vocabulary as the model-backed Trend column.
const MANUAL_KPI_TRENDS = ["Improving", "Needs Improvement", "Steady"] as const;

const MANUAL_KPI_HISTORY_FIELDS = [
  "kpi", "target", "value", "trend", "sortOrder", "active",
] as const;
type ManualKpiHistoryField = (typeof MANUAL_KPI_HISTORY_FIELDS)[number];

interface ManualKpiRow {
  kpi_key: string;
  kpi: string;
  target: string | null;
  value: string | null;
  trend: string | null;
  sort_order: number;
  active: number;
  updated_by: string | null;
  created_at: string;
  updated_at: string | null;
}

function manualKpiPayload(r: ManualKpiRow) {
  return {
    kpiKey: r.kpi_key,
    kpi: r.kpi,
    target: r.target,
    value: r.value,
    trend: r.trend,
    sortOrder: r.sort_order,
    active: !!r.active,
    updatedBy: r.updated_by,
    updatedAt: r.updated_at,
  };
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    if (path === "/health") return json({ ok: true }, 200, env);
    if (!authed(req, env)) return err(401, "unauthorized", env);

    try {
      // ─── Revision overrides ──────────────────────────────────────────────

      // Map keyed by revision_key — visual load + model refresh.
      if (req.method === "GET" && path === "/revision-overrides") {
        const rs = await env.DB.prepare(
          `SELECT revision_key, order_line_id, change_date, change_time,
                  revision_reason_override, note, exclude_flag,
                  created_at, updated_at
           FROM revision_overrides`
        ).all<RevisionOverrideRow>();
        const out: Record<string, ReturnType<typeof overridePayload>> = {};
        for (const r of rs.results) out[r.revision_key] = overridePayload(r);
        return json(out, 200, env);
      }

      // Partial upsert. Key + fields in the JSON body (key contains commas/
      // pipes). Omitted fields are preserved. Editing is open to anyone with the
      // shared secret (report access); x-actor-email is recorded for audit only.
      // Diffs into history.
      if (req.method === "PUT" && path === "/revision-override") {
        const b = (await req.json().catch(() => null)) as {
          revisionKey?: unknown;
          orderLineId?: unknown;
          changeDate?: unknown;
          changeTime?: unknown;
          revisionReason?: unknown;
          note?: unknown;
          excludeFlag?: unknown;
          createdAt?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const revisionKey = typeof b.revisionKey === "string" ? b.revisionKey.trim() : "";
        if (!revisionKey) return err(400, "revisionKey required", env);

        // revision_key opens with the Order Line ID, so its first comma segment is the company.
        {
          const perms = await actorPermissions(req, env);
          const company = companyOfOrderLineId(revisionKey);
          if (!mayEditCompany(perms, company)) return forbidden(perms, company, env);
        }

        const orderLineId = nullableString(b.orderLineId);
        const changeDate = nullableString(b.changeDate);
        const changeTime = nullableString(b.changeTime);
        const revisionReason = nullableString(b.revisionReason);
        const note = nullableString(b.note);
        const excludeFlag = boolFlag(b.excludeFlag);
        if (
          orderLineId === undefined &&
          changeDate === undefined &&
          changeTime === undefined &&
          revisionReason === undefined &&
          note === undefined &&
          excludeFlag === undefined
        ) {
          return err(400, "no fields to update", env);
        }

        const existing = await env.DB.prepare(
          `SELECT revision_key, order_line_id, change_date, change_time,
                  revision_reason_override, note, exclude_flag, created_at, updated_at
           FROM revision_overrides WHERE revision_key = ?`
        ).bind(revisionKey).first<RevisionOverrideRow>();

        const next = {
          orderLineId: orderLineId === undefined ? existing?.order_line_id ?? null : orderLineId,
          changeDate: changeDate === undefined ? existing?.change_date ?? null : changeDate,
          changeTime: changeTime === undefined ? existing?.change_time ?? null : changeTime,
          revisionReason:
            revisionReason === undefined ? existing?.revision_reason_override ?? null : revisionReason,
          note: note === undefined ? existing?.note ?? null : note,
          excludeFlag: excludeFlag === undefined ? existing?.exclude_flag ?? 0 : excludeFlag,
        };

        const actorEmail = actorEmailOf(req);
        const createdAtOverride =
          typeof b.createdAt === "string" && b.createdAt ? b.createdAt : null;

        const res = existing
          ? await env.DB.prepare(
              `UPDATE revision_overrides
               SET order_line_id = ?, change_date = ?, change_time = ?,
                   revision_reason_override = ?, note = ?, exclude_flag = ?,
                   updated_at = datetime('now')
               WHERE revision_key = ?
               RETURNING *`
            )
              .bind(
                next.orderLineId, next.changeDate, next.changeTime,
                next.revisionReason, next.note, next.excludeFlag, revisionKey
              )
              .first<RevisionOverrideRow>()
          : createdAtOverride
            ? await env.DB.prepare(
                `INSERT INTO revision_overrides
                   (revision_key, order_line_id, change_date, change_time,
                    revision_reason_override, note, exclude_flag, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                 RETURNING *`
              )
                .bind(
                  revisionKey, next.orderLineId, next.changeDate, next.changeTime,
                  next.revisionReason, next.note, next.excludeFlag,
                  createdAtOverride, createdAtOverride
                )
                .first<RevisionOverrideRow>()
            : await env.DB.prepare(
                `INSERT INTO revision_overrides
                   (revision_key, order_line_id, change_date, change_time,
                    revision_reason_override, note, exclude_flag)
                 VALUES (?, ?, ?, ?, ?, ?, ?)
                 RETURNING *`
              )
                .bind(
                  revisionKey, next.orderLineId, next.changeDate, next.changeTime,
                  next.revisionReason, next.note, next.excludeFlag
                )
                .first<RevisionOverrideRow>();
        if (!res) return err(500, "save failed", env);

        const prevValues: Record<HistoryField, string | null> = {
          revisionReason: existing?.revision_reason_override ?? null,
          note: existing?.note ?? null,
          excludeFlag: existing ? String(existing.exclude_flag) : null,
        };
        const nextValues: Record<HistoryField, string | null> = {
          revisionReason: next.revisionReason,
          note: next.note,
          excludeFlag: String(next.excludeFlag),
        };
        for (const field of HISTORY_FIELDS) {
          if (prevValues[field] === nextValues[field]) continue;
          await env.DB.prepare(
            `INSERT INTO override_history (revision_key, actor_email, field, old_value, new_value)
             VALUES (?, ?, ?, ?, ?)`
          ).bind(revisionKey, actorEmail, field, prevValues[field], nextValues[field]).run();
        }

        return json(overridePayload(res), existing ? 200 : 201, env);
      }

      // Key in body (commas/pipes). Open to anyone with the shared secret.
      if (req.method === "DELETE" && path === "/revision-override") {
        const b = (await req.json().catch(() => null)) as { revisionKey?: unknown } | null;
        const revisionKey = b && typeof b.revisionKey === "string" ? b.revisionKey.trim() : "";
        if (!revisionKey) return err(400, "revisionKey required", env);
        {
          const perms = await actorPermissions(req, env);
          const company = companyOfOrderLineId(revisionKey);
          if (!mayEditCompany(perms, company)) return forbidden(perms, company, env);
        }
        const res = await env.DB.prepare(
          `DELETE FROM revision_overrides WHERE revision_key = ? RETURNING revision_key`
        ).bind(revisionKey).first<{ revision_key: string }>();
        if (!res) return err(404, "not found", env);
        return json({ revisionKey: res.revision_key, deleted: true }, 200, env);
      }

      if (req.method === "GET" && path === "/history") {
        const revisionKey = url.searchParams.get("revisionKey");
        const since = url.searchParams.get("since");
        const before = url.searchParams.get("before");
        const limitRaw = Number(url.searchParams.get("limit"));
        const limit = Number.isFinite(limitRaw) && limitRaw > 0 && limitRaw <= 500
          ? Math.trunc(limitRaw)
          : 100;
        let sql = `SELECT history_id, revision_key, actor_email, changed_at, field, old_value, new_value
                   FROM override_history`;
        const where: string[] = [];
        const binds: unknown[] = [];
        if (revisionKey) {
          where.push("revision_key = ?");
          binds.push(revisionKey);
        }
        if (since) {
          where.push("changed_at >= ?");
          binds.push(since);
        }
        if (before) {
          where.push("changed_at < ?");
          binds.push(before);
        }
        if (where.length) sql += " WHERE " + where.join(" AND ");
        sql += " ORDER BY changed_at DESC, history_id DESC LIMIT ?";
        binds.push(limit);
        const rs = await env.DB.prepare(sql).bind(...binds).all<HistoryRow>();
        return json(rs.results.map(historyPayload), 200, env);
      }

      // ─── Line comments ───────────────────────────────────────────────────

      // Latest non-deleted comment per order_line_id — model refresh.
      if (req.method === "GET" && path === "/comments/latest") {
        const rs = await env.DB.prepare(
          `SELECT c.id, c.order_line_id, c.body, c.actor_email, c.created_at, c.updated_at
           FROM line_comments c
           JOIN (
             SELECT order_line_id, MAX(id) AS mx
             FROM line_comments
             WHERE deleted_at IS NULL
             GROUP BY order_line_id
           ) m ON m.order_line_id = c.order_line_id AND m.mx = c.id
           WHERE c.deleted_at IS NULL`
        ).all<CommentRow>();
        const out: Record<string, {
          id: number;
          body: string;
          actorEmail: string | null;
          createdAt: string;
          updatedAt: string | null;
        }> = {};
        for (const r of rs.results) {
          out[r.order_line_id] = {
            id: r.id,
            body: r.body,
            actorEmail: r.actor_email,
            createdAt: r.created_at,
            updatedAt: r.updated_at,
          };
        }
        return json(out, 200, env);
      }

      // Non-deleted comment count per order_line_id — grid count column.
      if (req.method === "GET" && path === "/comments/counts") {
        const rs = await env.DB.prepare(
          `SELECT order_line_id, COUNT(*) AS n
           FROM line_comments
           WHERE deleted_at IS NULL
           GROUP BY order_line_id`
        ).all<{ order_line_id: string; n: number }>();
        const out: Record<string, number> = {};
        for (const r of rs.results) out[r.order_line_id] = r.n;
        return json(out, 200, env);
      }

      if (req.method === "GET" && path === "/comments/thread") {
        const orderLineId = url.searchParams.get("orderLineId");
        if (!orderLineId) return err(400, "orderLineId required", env);
        const rs = await env.DB.prepare(
          `SELECT id, order_line_id, body, actor_email, created_at, updated_at
           FROM line_comments
           WHERE deleted_at IS NULL AND order_line_id = ?
           ORDER BY created_at ASC, id ASC`
        ).bind(orderLineId).all<CommentRow>();
        return json(rs.results.map(commentPayload), 200, env);
      }

      // Single-comment-per-line inline edit (used by the comments visual). Upsert
      // the latest non-deleted comment for a line: update it in place, or insert
      // if none; an empty/whitespace body soft-deletes the current one. Open to
      // anyone with the shared secret (report access); x-actor-email is recorded
      // as author for audit only. GET /comments/latest and /comments/counts are
      // unchanged so the model refresh still works.
      if (req.method === "PUT" && path === "/line-comment") {
        const b = (await req.json().catch(() => null)) as {
          orderLineId?: unknown;
          body?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const orderLineId = nullableString(b.orderLineId);
        if (!orderLineId) return err(400, "orderLineId required", env);

        // Company gate — the visual disables the cell too, this is the enforcement.
        const perms = await actorPermissions(req, env);
        const company = companyOfOrderLineId(orderLineId);
        if (!mayEditCompany(perms, company)) return forbidden(perms, company, env);

        const body = typeof b.body === "string" ? b.body.trim() : "";
        const actorEmail = perms.email;
        const existing = await env.DB.prepare(
          `SELECT id, body FROM line_comments
           WHERE order_line_id = ? AND deleted_at IS NULL
           ORDER BY id DESC LIMIT 1`
        ).bind(orderLineId).first<{ id: number; body: string }>();
        if (!body) {
          if (existing) {
            await env.DB.prepare(
              `UPDATE line_comments SET deleted_at = datetime('now') WHERE id = ?`
            ).bind(existing.id).run();
            await logComment(env, orderLineId, existing.id, actorEmail, "delete", existing.body, null);
          }
          return json({ orderLineId, deleted: true }, 200, env);
        }
        if (existing) {
          const res = await env.DB.prepare(
            `UPDATE line_comments SET body = ?, actor_email = ?, updated_at = datetime('now')
             WHERE id = ? RETURNING *`
          ).bind(body, actorEmail, existing.id).first<CommentRow>();
          if (!res) return err(500, "save failed", env);
          await logComment(env, orderLineId, existing.id, actorEmail, "edit", existing.body, body);
          return json(commentPayload(res), 200, env);
        }
        const res = await env.DB.prepare(
          `INSERT INTO line_comments (order_line_id, body, actor_email)
           VALUES (?, ?, ?) RETURNING *`
        ).bind(orderLineId, body, actorEmail).first<CommentRow>();
        if (!res) return err(500, "save failed", env);
        await logComment(env, orderLineId, res.id, actorEmail, "create", null, body);
        return json(commentPayload(res), 201, env);
      }

      // Open to anyone with the shared secret; x-actor-email recorded as author.
      if (req.method === "POST" && path === "/comment") {
        const b = (await req.json().catch(() => null)) as {
          orderLineId?: unknown;
          body?: unknown;
          createdAt?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const orderLineId = nullableString(b.orderLineId);
        const body = nullableString(b.body);
        if (!orderLineId) return err(400, "orderLineId required", env);
        if (!body) return err(400, "body required", env);
        const perms = await actorPermissions(req, env);
        const company = companyOfOrderLineId(orderLineId);
        if (!mayEditCompany(perms, company)) return forbidden(perms, company, env);
        const actorEmail = perms.email;
        const createdAt = typeof b.createdAt === "string" && b.createdAt ? b.createdAt : null;
        const res = createdAt
          ? await env.DB.prepare(
              `INSERT INTO line_comments (order_line_id, body, actor_email, created_at)
               VALUES (?, ?, ?, ?) RETURNING *`
            ).bind(orderLineId, body, actorEmail, createdAt).first<CommentRow>()
          : await env.DB.prepare(
              `INSERT INTO line_comments (order_line_id, body, actor_email)
               VALUES (?, ?, ?) RETURNING *`
            ).bind(orderLineId, body, actorEmail).first<CommentRow>();
        if (!res) return err(500, "save failed", env);
        await logComment(env, orderLineId, res.id, actorEmail, "create", null, body);
        return json(commentPayload(res), 201, env);
      }

      // Edit (PATCH) / soft-delete (DELETE) a single comment. Company-gated: the caller
      // must be an admin, or listed against the Order Company the comment belongs to.
      {
        const m = path.startsWith("/comment/") ? /^\/comment\/(\d+)$/.exec(path) : null;
        if (m && (req.method === "PATCH" || req.method === "DELETE")) {
          const id = Number(m[1]);
          const existing = await env.DB.prepare(
            `SELECT id, order_line_id, body, actor_email, created_at, updated_at, deleted_at
             FROM line_comments WHERE id = ? AND deleted_at IS NULL`
          ).bind(id).first<CommentRow>();
          if (!existing) return err(404, "not found", env);

          const perms = await actorPermissions(req, env);
          const company = companyOfOrderLineId(existing.order_line_id);
          if (!mayEditCompany(perms, company)) return forbidden(perms, company, env);

          if (req.method === "DELETE") {
            const res = await env.DB.prepare(
              `UPDATE line_comments SET deleted_at = datetime('now')
               WHERE id = ? AND deleted_at IS NULL RETURNING id`
            ).bind(id).first<{ id: number }>();
            if (!res) return err(404, "not found", env);
            await logComment(env, existing.order_line_id, id, perms.email, "delete", existing.body, null);
            return json({ id: res.id, deleted: true }, 200, env);
          }

          const b = (await req.json().catch(() => null)) as { body?: unknown } | null;
          const body = b ? nullableString(b.body) : undefined;
          if (!body) return err(400, "body required", env);
          const res = await env.DB.prepare(
            `UPDATE line_comments SET body = ?, updated_at = datetime('now')
             WHERE id = ? AND deleted_at IS NULL RETURNING *`
          ).bind(body, id).first<CommentRow>();
          if (!res) return err(404, "not found", env);
          await logComment(env, existing.order_line_id, id, perms.email, "edit", existing.body, body);
          return json(commentPayload(res), 200, env);
        }
      }

      // Comment audit trail — admin only, matching the Revision Log's /history.
      if (req.method === "GET" && path === "/comment-history") {
        const perms = await actorPermissions(req, env);
        if (!perms.isAdmin) return err(403, "admin required", env);
        const orderLineId = nullableString(url.searchParams.get("orderLineId"));
        const since = nullableString(url.searchParams.get("since"));
        const limitRaw = Number(url.searchParams.get("limit"));
        const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 1000) : 500;
        const where: string[] = [];
        const binds: unknown[] = [];
        if (orderLineId) { where.push("order_line_id = ?"); binds.push(orderLineId); }
        if (since) { where.push("changed_at >= ?"); binds.push(since); }
        binds.push(limit);
        const rs = await env.DB.prepare(
          `SELECT history_id, order_line_id, comment_id, actor_email, changed_at, action, old_value, new_value
           FROM comment_history
           ${where.length ? "WHERE " + where.join(" AND ") : ""}
           ORDER BY changed_at DESC, history_id DESC
           LIMIT ?`
        ).bind(...binds).all<CommentHistoryRow>();
        return json(rs.results.map(commentHistoryPayload), 200, env);
      }

      // ─── Board comments (page-level discussion thread) ───────────────────
      // Same edit model as line comments: the shared secret is report access, and anyone
      // holding it may post, edit or soft-delete. board_key namespaces threads per page.

      const DEFAULT_BOARD = "summary-shipped-as-promised";

      if (req.method === "GET" && path === "/board-comments") {
        const boardKey = nullableString(url.searchParams.get("board")) ?? DEFAULT_BOARD;
        const limitRaw = Number(url.searchParams.get("limit"));
        const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 500) : 200;

        // ?region=EMEA narrows to that region PLUS the untagged all-regions posts, so a
        // company-wide note stays on screen while a region is selected. Omit the param to
        // read the whole board. An unrecognised region is a client bug, not "show me all".
        const regionParam = url.searchParams.get("region");
        const where = ["board_key = ?", "deleted_at IS NULL"];
        const binds: unknown[] = [boardKey];
        if (regionParam !== null && regionParam.trim() !== "") {
          const region = normalizeRegion(regionParam);
          if (region === undefined) return err(400, `unknown region '${regionParam}'`, env);
          if (region !== null) {
            where.push("(region = ? OR region IS NULL)");
            binds.push(region);
          }
        }
        binds.push(limit);

        const rs = await env.DB.prepare(
          `SELECT id, board_key, body, region, actor_email, created_at, updated_at, deleted_at
           FROM board_comments
           WHERE ${where.join(" AND ")}
           ORDER BY created_at DESC, id DESC
           LIMIT ?`
        ).bind(...binds).all<BoardCommentRow>();
        return json(rs.results.map(boardCommentPayload), 200, env);
      }

      if (req.method === "POST" && path === "/board-comment") {
        const b = (await req.json().catch(() => null)) as {
          boardKey?: unknown;
          body?: unknown;
          region?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const body = nullableString(b.body);
        if (!body) return err(400, "body required", env);
        const boardKey = nullableString(b.boardKey) ?? DEFAULT_BOARD;
        const region = normalizeRegion(b.region);
        if (region === undefined) return err(400, `unknown region '${String(b.region)}'`, env);
        const res = await env.DB.prepare(
          `INSERT INTO board_comments (board_key, body, region, actor_email)
           VALUES (?, ?, ?, ?) RETURNING *`
        ).bind(boardKey, body, region, actorEmailOf(req)).first<BoardCommentRow>();
        if (!res) return err(500, "save failed", env);
        return json(boardCommentPayload(res), 201, env);
      }

      {
        const m = path.startsWith("/board-comment/") ? /^\/board-comment\/(\d+)$/.exec(path) : null;
        if (m && (req.method === "PATCH" || req.method === "DELETE")) {
          const id = Number(m[1]);
          if (req.method === "DELETE") {
            const res = await env.DB.prepare(
              `UPDATE board_comments SET deleted_at = datetime('now')
               WHERE id = ? AND deleted_at IS NULL RETURNING id`
            ).bind(id).first<{ id: number }>();
            if (!res) return err(404, "not found", env);
            return json({ id: res.id, deleted: true }, 200, env);
          }
          const b = (await req.json().catch(() => null)) as { body?: unknown; region?: unknown } | null;
          if (!b) return err(400, "bad json", env);

          // Either field alone is a valid edit — retagging a post's region shouldn't force the
          // client to round-trip its text. An absent `region` key leaves the tag alone; an
          // explicit null clears it back to "all regions".
          const sets: string[] = [];
          const binds: unknown[] = [];
          if ("body" in b) {
            const body = nullableString(b.body);
            if (!body) return err(400, "body required", env);
            sets.push("body = ?");
            binds.push(body);
          }
          if ("region" in b) {
            const region = normalizeRegion(b.region);
            if (region === undefined) return err(400, `unknown region '${String(b.region)}'`, env);
            sets.push("region = ?");
            binds.push(region);
          }
          if (!sets.length) return err(400, "body or region required", env);
          binds.push(id);

          const res = await env.DB.prepare(
            `UPDATE board_comments SET ${sets.join(", ")}, updated_at = datetime('now')
             WHERE id = ? AND deleted_at IS NULL RETURNING *`
          ).bind(...binds).first<BoardCommentRow>();
          if (!res) return err(404, "not found", env);
          return json(boardCommentPayload(res), 200, env);
        }
      }

      // ─── People / roles (admin manages) ──────────────────────────────────

      if (req.method === "GET" && path === "/people") {
        const rs = await env.DB.prepare(
          `SELECT person_key, person_name, display_name, email, role, active, created_at, updated_at
           FROM people
           ORDER BY active DESC, person_name COLLATE NOCASE`
        ).all<PersonRow>();
        // One extra read + group beats N per-person queries; the list is tens of rows.
        const cs = await env.DB.prepare(
          `SELECT person_key, company FROM people_companies ORDER BY company`
        ).all<{ person_key: string; company: string }>();
        const byPerson = new Map<string, string[]>();
        for (const r of cs.results) {
          const list = byPerson.get(r.person_key) ?? [];
          list.push(r.company);
          byPerson.set(r.person_key, list);
        }
        return json(
          rs.results.map((r) => ({ ...personPayload(r), companies: byPerson.get(r.person_key) ?? [] })),
          200,
          env
        );
      }

      if (req.method === "POST" && path === "/people") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as {
          personName?: unknown;
          displayName?: unknown;
          email?: unknown;
          role?: unknown;
          active?: unknown;
          companies?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const personName = nullableString(b.personName);
        if (!personName) return err(400, "personName required", env);
        const displayName = nullableString(b.displayName);
        const email = normalizeEmail(b.email);
        const role = normalizeRole(b.role);
        if (b.email !== undefined && email === undefined) return err(400, "invalid email", env);
        if (b.role !== undefined && role === undefined) return err(400, "invalid role", env);
        const active = b.active === undefined ? 1 : b.active ? 1 : 0;
        const res = await env.DB.prepare(
          `INSERT INTO people (person_key, person_name, display_name, email, role, active)
           VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(person_key) DO UPDATE SET
             person_name = excluded.person_name,
             display_name = COALESCE(excluded.display_name, people.display_name),
             email = COALESCE(excluded.email, people.email),
             role = COALESCE(excluded.role, people.role),
             active = excluded.active,
             updated_at = datetime('now')
           RETURNING *`
        ).bind(personKey(personName), personName, displayName ?? null, email ?? null, role ?? null, active)
          .first<PersonRow>();
        if (!res) return err(500, "save failed", env);
        const companies = await setPersonCompanies(env, res.person_key, b.companies);
        return json({ ...personPayload(res), companies: companies ?? [] }, 201, env);
      }

      if (req.method === "PUT" && path.startsWith("/people/")) {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const key = personKey(decodeURIComponent(path.slice("/people/".length)));
        if (!key) return err(400, "personKey required", env);
        const b = (await req.json().catch(() => null)) as {
          personName?: unknown;
          displayName?: unknown;
          email?: unknown;
          role?: unknown;
          active?: unknown;
          companies?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const existing = await env.DB.prepare(
          `SELECT person_key, person_name, display_name, email, role, active, created_at, updated_at
           FROM people WHERE person_key = ?`
        ).bind(key).first<PersonRow>();
        if (!existing) return err(404, "not found", env);

        const personName = nullableString(b.personName);
        const displayName = b.displayName === undefined ? undefined : nullableString(b.displayName);
        const email = normalizeEmail(b.email);
        const role = normalizeRole(b.role);
        if (b.email !== undefined && email === undefined) return err(400, "invalid email", env);
        if (b.role !== undefined && role === undefined) return err(400, "invalid role", env);
        const active = b.active === undefined ? existing.active : b.active ? 1 : 0;
        const res = await env.DB.prepare(
          `UPDATE people
           SET person_name = ?, display_name = ?, email = ?, role = ?, active = ?,
               updated_at = datetime('now')
           WHERE person_key = ?
           RETURNING *`
        )
          .bind(
            personName === undefined ? existing.person_name : personName,
            displayName === undefined ? existing.display_name : displayName,
            email === undefined ? existing.email : email,
            role === undefined ? existing.role : role,
            active,
            key
          )
          .first<PersonRow>();
        if (!res) return err(500, "update failed", env);
        const updatedCompanies = await setPersonCompanies(env, key, b.companies);
        const current = updatedCompanies ?? (
          await env.DB.prepare(`SELECT company FROM people_companies WHERE person_key = ? ORDER BY company`)
            .bind(key).all<{ company: string }>()
        ).results.map((r) => r.company);
        return json({ ...personPayload(res), companies: current }, 200, env);
      }

      // Default is the soft deactivate (row survives, greyed, reactivatable). `?hard=1`
      // is the People panel's Remove: the row and its company grants go for good. Nothing
      // has an FK onto person_key, and both history tables record actor_email rather than
      // the key, so a hard delete costs no audit trail — it only drops the display name
      // those logs would otherwise resolve the email to.
      if (req.method === "DELETE" && path.startsWith("/people/")) {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const key = personKey(decodeURIComponent(path.slice("/people/".length)));
        if (!key) return err(400, "personKey required", env);

        if (url.searchParams.get("hard") === "1") {
          // Deleting your own row revokes your own admin rights, and there is no way back
          // in through the UI afterwards. Refuse and say why rather than locking the
          // caller out of the panel they are standing in.
          const self = await env.DB.prepare(
            `SELECT person_key FROM people WHERE email = ? AND active = 1 LIMIT 1`
          ).bind(actorEmailOf(req)).first<{ person_key: string }>();
          if (self && self.person_key === key) return err(409, "you cannot delete your own account", env);
          const existing = await env.DB.prepare(
            `SELECT person_key FROM people WHERE person_key = ?`
          ).bind(key).first<{ person_key: string }>();
          if (!existing) return err(404, "not found", env);
          await env.DB.prepare(`DELETE FROM people_companies WHERE person_key = ?`).bind(key).run();
          await env.DB.prepare(`DELETE FROM people WHERE person_key = ?`).bind(key).run();
          return json({ personKey: key, deleted: true }, 200, env);
        }

        const res = await env.DB.prepare(
          `UPDATE people SET active = 0, updated_at = datetime('now')
           WHERE person_key = ? RETURNING *`
        ).bind(key).first<PersonRow>();
        if (!res) return err(404, "not found", env);
        // Companies survive a deactivate, so return them — a payload without them reads
        // as "read-only" in the panel and silently contradicts what a reactivate restores.
        const companies = (
          await env.DB.prepare(`SELECT company FROM people_companies WHERE person_key = ? ORDER BY company`)
            .bind(key).all<{ company: string }>()
        ).results.map((r) => r.company);
        return json({ ...personPayload(res), companies }, 200, env);
      }

      // ─── Reason codes (admin CRUD; rename cascades to overrides) ──────────

      if (req.method === "GET" && path === "/reason-codes") {
        const rs = await env.DB.prepare(
          `SELECT code_id, code, label, sort_order, active, created_at, updated_at
           FROM dropdown_reason_codes
           ORDER BY active DESC, sort_order, code COLLATE NOCASE`
        ).all<ReasonCodeRow>();
        return json(rs.results.map(reasonCodePayload), 200, env);
      }

      if (req.method === "POST" && path === "/reason-codes") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as {
          code?: unknown;
          label?: unknown;
          sortOrder?: unknown;
          active?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const code = nullableString(b.code);
        if (!code) return err(400, "code required", env);
        const label = nullableString(b.label);
        const sortOrder = typeof b.sortOrder === "number" && Number.isFinite(b.sortOrder)
          ? Math.trunc(b.sortOrder)
          : 1000;
        const active = b.active === undefined ? 1 : b.active ? 1 : 0;
        const dup = await env.DB.prepare(
          `SELECT code_id FROM dropdown_reason_codes WHERE code = ?`
        ).bind(code).first<{ code_id: number }>();
        if (dup) return err(409, "code already exists", env);
        const res = await env.DB.prepare(
          `INSERT INTO dropdown_reason_codes (code, label, sort_order, active)
           VALUES (?, ?, ?, ?) RETURNING *`
        ).bind(code, label ?? null, sortOrder, active).first<ReasonCodeRow>();
        if (!res) return err(500, "save failed", env);
        return json(reasonCodePayload(res), 201, env);
      }

      {
        const m = path.startsWith("/reason-codes/") ? /^\/reason-codes\/(\d+)$/.exec(path) : null;
        if (m && (req.method === "PUT" || req.method === "DELETE")) {
          if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
          const codeId = Number(m[1]);
          const existing = await env.DB.prepare(
            `SELECT code_id, code, label, sort_order, active, created_at, updated_at
             FROM dropdown_reason_codes WHERE code_id = ?`
          ).bind(codeId).first<ReasonCodeRow>();
          if (!existing) return err(404, "not found", env);

          if (req.method === "DELETE") {
            const res = await env.DB.prepare(
              `UPDATE dropdown_reason_codes SET active = 0, updated_at = datetime('now')
               WHERE code_id = ? RETURNING *`
            ).bind(codeId).first<ReasonCodeRow>();
            if (!res) return err(500, "delete failed", env);
            return json(reasonCodePayload(res), 200, env);
          }

          const b = (await req.json().catch(() => null)) as {
            code?: unknown;
            label?: unknown;
            sortOrder?: unknown;
            active?: unknown;
          } | null;
          if (!b) return err(400, "bad json", env);
          const code = b.code === undefined ? undefined : nullableString(b.code);
          if (b.code !== undefined && !code) return err(400, "code cannot be empty", env);
          if (code && code !== existing.code) {
            const dup = await env.DB.prepare(
              `SELECT code_id FROM dropdown_reason_codes WHERE code = ? AND code_id != ?`
            ).bind(code, codeId).first<{ code_id: number }>();
            if (dup) return err(409, "code already exists", env);
          }
          const label = b.label === undefined ? existing.label : nullableString(b.label);
          const sortOrder = typeof b.sortOrder === "number" && Number.isFinite(b.sortOrder)
            ? Math.trunc(b.sortOrder)
            : existing.sort_order;
          const active = b.active === undefined ? existing.active : b.active ? 1 : 0;
          const res = await env.DB.prepare(
            `UPDATE dropdown_reason_codes
             SET code = ?, label = ?, sort_order = ?, active = ?, updated_at = datetime('now')
             WHERE code_id = ? RETURNING *`
          ).bind(code ?? existing.code, label ?? null, sortOrder, active, codeId).first<ReasonCodeRow>();
          if (!res) return err(500, "update failed", env);

          // Cascade a code rename onto stored overrides so they keep resolving.
          if (code && code !== existing.code) {
            await env.DB.prepare(
              `UPDATE revision_overrides
               SET revision_reason_override = ?, updated_at = datetime('now')
               WHERE revision_reason_override = ?`
            ).bind(code, existing.code).run();
          }
          return json(reasonCodePayload(res), 200, env);
        }
      }

      // ─── Reason code dimension (admin-gated writes; drives OTIF on refresh) ─
      // The editable reason-code dimension that REPLACES the SharePoint
      // spreadsheet. `code` is the UDC 42/RR value; `otif`=1 => a revision with
      // this code is an OTIF miss (drives 'Reason Codes'[OTIF]); `active`=0 is a
      // retired dim row. Returned as an ordered array for both the visual and the
      // model refresh (edw_model/ReasonDim.m loads it as the 'Reason Codes' table).
      // GET is open (x-secret only) so anyone with report access can view; PUT /
      // DELETE require an `admin` role in `people` (this table drives OTIF, so
      // edits are restricted). The extra spreadsheet columns (review_530,
      // review_540, typical_hit, old_classification, usage_examples, region_note)
      // are carried through verbatim so no source data is lost.

      if (req.method === "GET" && path === "/reason-dim") {
        const rs = await env.DB.prepare(
          `SELECT code, description, long_description, exemption_criteria,
                  otif, category, review_530, review_540, typical_hit,
                  old_classification, usage_examples, region_note,
                  active, sort_order, updated_by, created_at, updated_at
           FROM reason_dim
           ORDER BY sort_order, code COLLATE NOCASE`
        ).all<ReasonDimRow>();
        return json(rs.results.map(reasonDimPayload), 200, env);
      }

      // Partial upsert. Key + fields in the JSON body; omitted fields preserved.
      // Admin only (this table drives OTIF). Diffs into reason_dim_history.
      if (req.method === "PUT" && path === "/reason-dim") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as {
          code?: unknown;
          description?: unknown;
          longDescription?: unknown;
          exemptionCriteria?: unknown;
          otif?: unknown;
          category?: unknown;
          review530?: unknown;
          review540?: unknown;
          typicalHit?: unknown;
          oldClassification?: unknown;
          usageExamples?: unknown;
          regionNote?: unknown;
          active?: unknown;
          sortOrder?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const code = typeof b.code === "string" ? b.code.trim() : "";
        if (!code) return err(400, "code required", env);

        const description = nullableString(b.description);
        const longDescription = nullableString(b.longDescription);
        const exemptionCriteria = nullableString(b.exemptionCriteria);
        const otif = boolFlag(b.otif);
        const category = nullableString(b.category);
        const review530 = boolFlag(b.review530);
        const review540 = boolFlag(b.review540);
        const typicalHit = boolFlag(b.typicalHit);
        const oldClassification = nullableString(b.oldClassification);
        const usageExamples = nullableString(b.usageExamples);
        const regionNote = nullableString(b.regionNote);
        const active = boolFlag(b.active);
        const sortOrder =
          typeof b.sortOrder === "number" && Number.isFinite(b.sortOrder)
            ? Math.trunc(b.sortOrder)
            : undefined;
        if (
          description === undefined &&
          longDescription === undefined &&
          exemptionCriteria === undefined &&
          otif === undefined &&
          category === undefined &&
          review530 === undefined &&
          review540 === undefined &&
          typicalHit === undefined &&
          oldClassification === undefined &&
          usageExamples === undefined &&
          regionNote === undefined &&
          active === undefined &&
          sortOrder === undefined
        ) {
          return err(400, "no fields to update", env);
        }

        // Classification is a managed picklist (reason_categories), not free text: the
        // seed found "Operations" sitting next to "Operations (??)". The dropdown in the
        // visual is UX; this is the actual control. Clearing to null stays allowed.
        if (typeof category === "string") {
          const known = await env.DB.prepare(
            `SELECT name FROM reason_categories WHERE name = ? AND active = 1`
          ).bind(category).first<{ name: string }>();
          if (!known) {
            return err(
              400,
              `unknown classification "${category}" — add it under Classifications first`,
              env
            );
          }
        }

        const existing = await env.DB.prepare(
          `SELECT code, description, long_description, exemption_criteria,
                  otif, category, review_530, review_540, typical_hit,
                  old_classification, usage_examples, region_note,
                  active, sort_order, updated_by, created_at, updated_at
           FROM reason_dim WHERE code = ?`
        ).bind(code).first<ReasonDimRow>();

        const next = {
          description: description === undefined ? existing?.description ?? null : description,
          longDescription:
            longDescription === undefined ? existing?.long_description ?? null : longDescription,
          exemptionCriteria:
            exemptionCriteria === undefined ? existing?.exemption_criteria ?? null : exemptionCriteria,
          otif: otif === undefined ? existing?.otif ?? 0 : otif,
          category: category === undefined ? existing?.category ?? null : category,
          review530: review530 === undefined ? existing?.review_530 ?? 0 : review530,
          review540: review540 === undefined ? existing?.review_540 ?? 0 : review540,
          typicalHit: typicalHit === undefined ? existing?.typical_hit ?? 0 : typicalHit,
          oldClassification:
            oldClassification === undefined ? existing?.old_classification ?? null : oldClassification,
          usageExamples: usageExamples === undefined ? existing?.usage_examples ?? null : usageExamples,
          regionNote: regionNote === undefined ? existing?.region_note ?? null : regionNote,
          active: active === undefined ? existing?.active ?? 1 : active,
          sortOrder: sortOrder === undefined ? existing?.sort_order ?? 1000 : sortOrder,
        };

        const actorEmail = actorEmailOf(req);
        const res = existing
          ? await env.DB.prepare(
              `UPDATE reason_dim
               SET description = ?, long_description = ?, exemption_criteria = ?,
                   otif = ?, category = ?, review_530 = ?, review_540 = ?,
                   typical_hit = ?, old_classification = ?, usage_examples = ?,
                   region_note = ?, active = ?, sort_order = ?,
                   updated_by = ?, updated_at = datetime('now')
               WHERE code = ?
               RETURNING *`
            )
              .bind(
                next.description, next.longDescription, next.exemptionCriteria,
                next.otif, next.category, next.review530, next.review540,
                next.typicalHit, next.oldClassification, next.usageExamples,
                next.regionNote, next.active, next.sortOrder, actorEmail, code
              )
              .first<ReasonDimRow>()
          : await env.DB.prepare(
              `INSERT INTO reason_dim
                 (code, description, long_description, exemption_criteria,
                  otif, category, review_530, review_540, typical_hit,
                  old_classification, usage_examples, region_note,
                  active, sort_order, updated_by)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
               RETURNING *`
            )
              .bind(
                code, next.description, next.longDescription, next.exemptionCriteria,
                next.otif, next.category, next.review530, next.review540,
                next.typicalHit, next.oldClassification, next.usageExamples,
                next.regionNote, next.active, next.sortOrder, actorEmail
              )
              .first<ReasonDimRow>();
        if (!res) return err(500, "save failed", env);

        const prevValues: Record<ReasonDimHistoryField, string | null> = {
          description: existing?.description ?? null,
          longDescription: existing?.long_description ?? null,
          exemptionCriteria: existing?.exemption_criteria ?? null,
          otif: existing ? String(existing.otif) : null,
          category: existing?.category ?? null,
          review530: existing ? String(existing.review_530) : null,
          review540: existing ? String(existing.review_540) : null,
          typicalHit: existing ? String(existing.typical_hit) : null,
          oldClassification: existing?.old_classification ?? null,
          usageExamples: existing?.usage_examples ?? null,
          regionNote: existing?.region_note ?? null,
          active: existing ? String(existing.active) : null,
          sortOrder: existing ? String(existing.sort_order) : null,
        };
        const nextValues: Record<ReasonDimHistoryField, string | null> = {
          description: next.description,
          longDescription: next.longDescription,
          exemptionCriteria: next.exemptionCriteria,
          otif: String(next.otif),
          category: next.category,
          review530: String(next.review530),
          review540: String(next.review540),
          typicalHit: String(next.typicalHit),
          oldClassification: next.oldClassification,
          usageExamples: next.usageExamples,
          regionNote: next.regionNote,
          active: String(next.active),
          sortOrder: String(next.sortOrder),
        };
        for (const field of REASON_DIM_HISTORY_FIELDS) {
          if (prevValues[field] === nextValues[field]) continue;
          await env.DB.prepare(
            `INSERT INTO reason_dim_history (code, actor_email, field, old_value, new_value)
             VALUES (?, ?, ?, ?, ?)`
          ).bind(code, actorEmail, field, prevValues[field], nextValues[field]).run();
        }

        return json(reasonDimPayload(res), existing ? 200 : 201, env);
      }

      // Soft delete = retire the dim row (active=0). Keeps history; does not
      // change the otif flag. Admin only.
      if (req.method === "DELETE" && path === "/reason-dim") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as { code?: unknown } | null;
        const code = b && typeof b.code === "string" ? b.code.trim() : "";
        if (!code) return err(400, "code required", env);
        const existing = await env.DB.prepare(
          `SELECT active FROM reason_dim WHERE code = ?`
        ).bind(code).first<{ active: number }>();
        if (!existing) return err(404, "not found", env);
        const res = await env.DB.prepare(
          `UPDATE reason_dim SET active = 0, updated_by = ?, updated_at = datetime('now')
           WHERE code = ? RETURNING *`
        ).bind(actorEmailOf(req), code).first<ReasonDimRow>();
        if (!res) return err(500, "delete failed", env);
        if (existing.active !== 0) {
          await env.DB.prepare(
            `INSERT INTO reason_dim_history (code, actor_email, field, old_value, new_value)
             VALUES (?, ?, 'active', ?, '0')`
          ).bind(code, actorEmailOf(req), String(existing.active)).run();
        }
        return json(reasonDimPayload(res), 200, env);
      }

      if (req.method === "GET" && path === "/reason-dim/history") {
        const code = url.searchParams.get("code");
        const since = url.searchParams.get("since");
        const before = url.searchParams.get("before");
        const limitRaw = Number(url.searchParams.get("limit"));
        const limit = Number.isFinite(limitRaw) && limitRaw > 0 && limitRaw <= 500
          ? Math.trunc(limitRaw)
          : 100;
        let sql = `SELECT history_id, code, actor_email, changed_at, field, old_value, new_value
                   FROM reason_dim_history`;
        const where: string[] = [];
        const binds: unknown[] = [];
        if (code) { where.push("code = ?"); binds.push(code); }
        if (since) { where.push("changed_at >= ?"); binds.push(since); }
        if (before) { where.push("changed_at < ?"); binds.push(before); }
        if (where.length) sql += " WHERE " + where.join(" AND ");
        sql += " ORDER BY changed_at DESC, history_id DESC LIMIT ?";
        binds.push(limit);
        const rs = await env.DB.prepare(sql).bind(...binds).all<{
          history_id: number; code: string; actor_email: string | null;
          changed_at: string; field: string; old_value: string | null; new_value: string | null;
        }>();
        return json(rs.results.map((r) => ({
          historyId: r.history_id,
          code: r.code,
          actorEmail: r.actor_email,
          changedAt: r.changed_at,
          field: r.field,
          oldValue: r.old_value,
          newValue: r.new_value,
        })), 200, env);
      }

      // ─── Classification picklist (Reason Code Editor dropdown) ────────────
      // The managed list of allowed reason_dim.category values. GET is open (every
      // viewer needs it to render the dropdown); writes are admin-only, like the
      // dimension itself. Deliberately not a FK on reason_dim.category: a retired
      // choice must keep resolving for the rows that still carry it, exactly as a
      // retired reason code keeps resolving for historical facts.

      if (req.method === "GET" && path === "/reason-categories") {
        const rs = await env.DB.prepare(
          `SELECT rc.name, rc.sort_order, rc.active, rc.updated_by, rc.updated_at,
                  (SELECT COUNT(*) FROM reason_dim d WHERE d.category = rc.name) AS in_use
           FROM reason_categories rc
           ORDER BY rc.sort_order, rc.name COLLATE NOCASE`
        ).all<ReasonCategoryRow>();
        return json(rs.results.map(reasonCategoryPayload), 200, env);
      }

      // Upsert a choice, or rename one. A rename CASCADES to reason_dim.category and
      // logs a 'category' row per affected code into reason_dim_history, so the
      // reclassification shows up in each code's history panel rather than appearing
      // to have happened by itself. Renaming onto an existing name merges the two.
      if (req.method === "PUT" && path === "/reason-categories") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as {
          name?: unknown;
          renameFrom?: unknown;
          sortOrder?: unknown;
          active?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const name = typeof b.name === "string" ? b.name.trim() : "";
        if (!name) return err(400, "name required", env);
        const renameFrom = typeof b.renameFrom === "string" ? b.renameFrom.trim() : "";
        const sortOrder =
          typeof b.sortOrder === "number" && Number.isFinite(b.sortOrder)
            ? Math.trunc(b.sortOrder)
            : undefined;
        const active = boolFlag(b.active);
        const actorEmail = actorEmailOf(req);

        if (renameFrom && renameFrom !== name) {
          const old = await env.DB.prepare(
            `SELECT name, sort_order, active FROM reason_categories WHERE name = ?`
          ).bind(renameFrom).first<{ name: string; sort_order: number; active: number }>();
          if (!old) return err(404, `classification "${renameFrom}" not found`, env);

          const affected = await env.DB.prepare(
            `SELECT code FROM reason_dim WHERE category = ?`
          ).bind(renameFrom).all<{ code: string }>();

          // Land the new name first so the cascade never points at a missing choice.
          await env.DB.prepare(
            `INSERT INTO reason_categories (name, sort_order, active, updated_by)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(name) DO UPDATE SET
               sort_order = excluded.sort_order,
               active = excluded.active,
               updated_by = excluded.updated_by,
               updated_at = datetime('now')`
          )
            .bind(name, sortOrder ?? old.sort_order, active ?? old.active, actorEmail)
            .run();

          await env.DB.prepare(
            `UPDATE reason_dim SET category = ?, updated_by = ?, updated_at = datetime('now')
             WHERE category = ?`
          ).bind(name, actorEmail, renameFrom).run();

          for (const r of affected.results) {
            await env.DB.prepare(
              `INSERT INTO reason_dim_history (code, actor_email, field, old_value, new_value)
               VALUES (?, ?, 'category', ?, ?)`
            ).bind(r.code, actorEmail, renameFrom, name).run();
          }

          await env.DB.prepare(`DELETE FROM reason_categories WHERE name = ?`)
            .bind(renameFrom).run();

          const res = await env.DB.prepare(
            `SELECT rc.name, rc.sort_order, rc.active, rc.updated_by, rc.updated_at,
                    (SELECT COUNT(*) FROM reason_dim d WHERE d.category = rc.name) AS in_use
             FROM reason_categories rc WHERE rc.name = ?`
          ).bind(name).first<ReasonCategoryRow>();
          if (!res) return err(500, "rename failed", env);
          return json(reasonCategoryPayload(res), 200, env);
        }

        const existing = await env.DB.prepare(
          `SELECT name FROM reason_categories WHERE name = ?`
        ).bind(name).first<{ name: string }>();

        await env.DB.prepare(
          `INSERT INTO reason_categories (name, sort_order, active, updated_by)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(name) DO UPDATE SET
             sort_order = COALESCE(?, reason_categories.sort_order),
             active = COALESCE(?, reason_categories.active),
             updated_by = excluded.updated_by,
             updated_at = datetime('now')`
        )
          .bind(name, sortOrder ?? 1000, active ?? 1, actorEmail, sortOrder ?? null, active ?? null)
          .run();

        const res = await env.DB.prepare(
          `SELECT rc.name, rc.sort_order, rc.active, rc.updated_by, rc.updated_at,
                  (SELECT COUNT(*) FROM reason_dim d WHERE d.category = rc.name) AS in_use
           FROM reason_categories rc WHERE rc.name = ?`
        ).bind(name).first<ReasonCategoryRow>();
        if (!res) return err(500, "save failed", env);
        return json(reasonCategoryPayload(res), existing ? 200 : 201, env);
      }

      // Remove a choice. Refuses (409) while reason codes still carry it, and says how
      // many — an unused typo can be deleted outright, but a live one must be renamed
      // or reassigned first so no row is left pointing at nothing.
      if (req.method === "DELETE" && path === "/reason-categories") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as { name?: unknown } | null;
        const name = b && typeof b.name === "string" ? b.name.trim() : "";
        if (!name) return err(400, "name required", env);
        const existing = await env.DB.prepare(
          `SELECT name FROM reason_categories WHERE name = ?`
        ).bind(name).first<{ name: string }>();
        if (!existing) return err(404, "not found", env);
        const used = await env.DB.prepare(
          `SELECT COUNT(*) AS n FROM reason_dim WHERE category = ?`
        ).bind(name).first<{ n: number }>();
        if ((used?.n ?? 0) > 0) {
          return err(
            409,
            `"${name}" is still used by ${used?.n} reason code${used?.n === 1 ? "" : "s"} — rename it onto another choice instead`,
            env
          );
        }
        await env.DB.prepare(`DELETE FROM reason_categories WHERE name = ?`).bind(name).run();
        return json({ deleted: true, name }, 200, env);
      }

      // ─── Manual KPIs (Executive Scorecard section 3) ──────────────────────
      // Hand-maintained rows with no model backing, served straight to the
      // Scorecard KPIs visual. GET is open (x-secret only) so viewing always
      // works; writes need an admin or editor role — org-level content, so
      // company scope does not apply.

      if (req.method === "GET" && path === "/manual-kpis") {
        const rs = await env.DB.prepare(
          `SELECT kpi_key, kpi, target, value, trend, sort_order, active,
                  updated_by, created_at, updated_at
           FROM manual_kpis
           WHERE active = 1
           ORDER BY sort_order, kpi COLLATE NOCASE`
        ).all<ManualKpiRow>();
        return json(rs.results.map(manualKpiPayload), 200, env);
      }

      // Partial upsert by kpiKey; omitted fields preserved. Diffs into
      // manual_kpi_history.
      if (req.method === "PUT" && path === "/manual-kpis") {
        const role = await actorRole(req, env);
        if (role !== "admin" && role !== "editor") return err(403, "editor or admin required", env);
        const b = (await req.json().catch(() => null)) as {
          kpiKey?: unknown;
          kpi?: unknown;
          target?: unknown;
          value?: unknown;
          trend?: unknown;
          sortOrder?: unknown;
          active?: unknown;
        } | null;
        if (!b) return err(400, "bad json", env);
        const kpiKey = typeof b.kpiKey === "string" ? b.kpiKey.trim() : "";
        if (!kpiKey) return err(400, "kpiKey required", env);

        const kpi = nullableString(b.kpi);
        const target = b.target === null ? null : nullableString(b.target);
        const value = b.value === null ? null : nullableString(b.value);
        const trend = b.trend === null ? null : nullableString(b.trend);
        const sortOrder =
          typeof b.sortOrder === "number" && Number.isFinite(b.sortOrder)
            ? Math.trunc(b.sortOrder)
            : undefined;
        const active = boolFlag(b.active);
        if (
          kpi === undefined &&
          b.target === undefined &&
          b.value === undefined &&
          b.trend === undefined &&
          sortOrder === undefined &&
          active === undefined
        ) {
          return err(400, "no fields to update", env);
        }

        // Same posture as board_comments.region: an unrecognised verdict is a 400,
        // never a silent fourth bucket. Explicit null clears the verdict.
        if (typeof trend === "string" && !(MANUAL_KPI_TRENDS as readonly string[]).includes(trend)) {
          return err(400, `trend must be one of ${MANUAL_KPI_TRENDS.join(", ")} or null`, env);
        }

        const existing = await env.DB.prepare(
          `SELECT kpi_key, kpi, target, value, trend, sort_order, active,
                  updated_by, created_at, updated_at
           FROM manual_kpis WHERE kpi_key = ?`
        ).bind(kpiKey).first<ManualKpiRow>();

        const next = {
          kpi: kpi === undefined ? existing?.kpi ?? kpiKey : kpi,
          target: b.target === undefined ? existing?.target ?? null : target ?? null,
          value: b.value === undefined ? existing?.value ?? null : value ?? null,
          trend: b.trend === undefined ? existing?.trend ?? null : trend ?? null,
          sortOrder: sortOrder === undefined ? existing?.sort_order ?? 1000 : sortOrder,
          active: active === undefined ? existing?.active ?? 1 : active,
        };

        const actorEmail = actorEmailOf(req);
        const res = existing
          ? await env.DB.prepare(
              `UPDATE manual_kpis
               SET kpi = ?, target = ?, value = ?, trend = ?, sort_order = ?, active = ?,
                   updated_by = ?, updated_at = datetime('now')
               WHERE kpi_key = ?
               RETURNING *`
            )
              .bind(
                next.kpi, next.target, next.value, next.trend,
                next.sortOrder, next.active, actorEmail, kpiKey
              )
              .first<ManualKpiRow>()
          : await env.DB.prepare(
              `INSERT INTO manual_kpis
                 (kpi_key, kpi, target, value, trend, sort_order, active, updated_by)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               RETURNING *`
            )
              .bind(
                kpiKey, next.kpi, next.target, next.value, next.trend,
                next.sortOrder, next.active, actorEmail
              )
              .first<ManualKpiRow>();
        if (!res) return err(500, "save failed", env);

        const prevValues: Record<ManualKpiHistoryField, string | null> = {
          kpi: existing?.kpi ?? null,
          target: existing?.target ?? null,
          value: existing?.value ?? null,
          trend: existing?.trend ?? null,
          sortOrder: existing ? String(existing.sort_order) : null,
          active: existing ? String(existing.active) : null,
        };
        const nextValues: Record<ManualKpiHistoryField, string | null> = {
          kpi: next.kpi,
          target: next.target,
          value: next.value,
          trend: next.trend,
          sortOrder: String(next.sortOrder),
          active: String(next.active),
        };
        for (const field of MANUAL_KPI_HISTORY_FIELDS) {
          if (prevValues[field] === nextValues[field]) continue;
          await env.DB.prepare(
            `INSERT INTO manual_kpi_history (kpi_key, actor_email, field, old_value, new_value)
             VALUES (?, ?, ?, ?, ?)`
          ).bind(kpiKey, actorEmail, field, prevValues[field], nextValues[field]).run();
        }

        return json(manualKpiPayload(res), existing ? 200 : 201, env);
      }

      // Soft retire (active = 0). Keeps history. Admin only.
      if (req.method === "DELETE" && path === "/manual-kpis") {
        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);
        const b = (await req.json().catch(() => null)) as { kpiKey?: unknown } | null;
        const kpiKey = b && typeof b.kpiKey === "string" ? b.kpiKey.trim() : "";
        if (!kpiKey) return err(400, "kpiKey required", env);
        const existing = await env.DB.prepare(
          `SELECT active FROM manual_kpis WHERE kpi_key = ?`
        ).bind(kpiKey).first<{ active: number }>();
        if (!existing) return err(404, "not found", env);
        await env.DB.prepare(
          `UPDATE manual_kpis
           SET active = 0, updated_by = ?, updated_at = datetime('now')
           WHERE kpi_key = ?`
        ).bind(actorEmailOf(req), kpiKey).run();
        if (existing.active) {
          await env.DB.prepare(
            `INSERT INTO manual_kpi_history (kpi_key, actor_email, field, old_value, new_value)
             VALUES (?, ?, 'active', '1', '0')`
          ).bind(kpiKey, actorEmailOf(req)).run();
        }
        return json({ deleted: true, kpiKey }, 200, env);
      }

      // ─── Shared table layout (column order) ───────────────────────────────
      // One admin-managed default per visual. persistProperties does not survive the
      // Service, so the report-wide default lives here and loads for every viewer.
      if (path === "/layout" && (req.method === "GET" || req.method === "PUT" || req.method === "DELETE")) {
        const sharedLayoutEmail = "__shared__";
        const visual = (url.searchParams.get("visual") || "").trim().toLowerCase();
        if (visual !== "revisions" && visual !== "comments" && visual !== "reasondim") {
          return err(400, "visual must be revisions, comments or reasondim", env);
        }

        if (req.method === "GET") {
          const row = await env.DB.prepare(
            `SELECT column_order FROM user_layout WHERE email = ? AND visual_id = ?`
          ).bind(sharedLayoutEmail, visual).first<{ column_order: string }>();
          let columnOrder: string[] | null = null;
          if (row) {
            try {
              const p = JSON.parse(row.column_order);
              if (Array.isArray(p)) columnOrder = p.filter((x): x is string => typeof x === "string");
            } catch {
              columnOrder = null;
            }
          }
          return json({ columnOrder }, 200, env);
        }

        if ((await actorRole(req, env)) !== "admin") return err(403, "admin required", env);

        if (req.method === "DELETE") {
          await env.DB.prepare(
            `DELETE FROM user_layout WHERE email = ? AND visual_id = ?`
          ).bind(sharedLayoutEmail, visual).run();
          return json({ deleted: true }, 200, env);
        }

        const b = (await req.json().catch(() => null)) as { columnOrder?: unknown } | null;
        if (!b || !Array.isArray(b.columnOrder)) return err(400, "columnOrder array required", env);
        const order = b.columnOrder.filter((x): x is string => typeof x === "string");
        await env.DB.prepare(
          `INSERT INTO user_layout (email, visual_id, column_order, updated_at)
           VALUES (?, ?, ?, datetime('now'))
           ON CONFLICT(email, visual_id) DO UPDATE SET
             column_order = excluded.column_order,
             updated_at = datetime('now')`
        ).bind(sharedLayoutEmail, visual, JSON.stringify(order)).run();
        return json({ columnOrder: order }, 200, env);
      }

      return err(404, "not found", env);
    } catch (e) {
      return err(500, e instanceof Error ? e.message : "internal error", env);
    }
  },
} satisfies ExportedHandler<Env>;
