// Company-scoped edit rights, mirroring the Worker's actorPermissions/mayEditCompany.
// The visual uses this to disable cells; the Worker enforces it for real. Keeping the
// two in step is deliberate — a disabled cell is UX, the 403 is the actual control.
//
// Model (agreed 2026-07-28): admin edits every company and manages the People list;
// everyone else edits exactly the companies listed against their email; nobody listed,
// or listed with no companies, is read-only. The old editor/restricted roles no longer
// gate editing.

import { Person } from "./api";

/** Canonical company code — '10' / '0010' / '00010' all collapse to '00010'. */
export function normalizeCompany(raw: string | null | undefined): string | null {
    if (raw == null) return null;
    const t = String(raw).trim();
    if (!t) return null;
    if (!/^\d+$/.test(t)) return t.toUpperCase();
    return t.replace(/^0+/, "").padStart(5, "0");
}

/**
 * A row's owning company, read off the Order Line ID ("00010,74,CM,4.000" -> "00010").
 * Both grids already bind that key, so no extra field well is needed. The revision key
 * ("<orderLineId>|<date>|<time>") starts with the same segment, so it works there too.
 */
export function companyOfKey(key: string | null | undefined): string | null {
    if (!key) return null;
    return normalizeCompany(String(key).split(",")[0]);
}

export interface Permissions {
    /** Matched, active person for the viewer — null when they are not on the list. */
    person: Person | null;
    isAdmin: boolean;
    companies: string[];
    /** May the viewer edit rows for this company? */
    canEditCompany: (company: string | null) => boolean;
    /** May the viewer edit the row behind this Order Line ID / revision key? */
    canEditKey: (key: string | null | undefined) => boolean;
    /** Why editing is blocked, for a tooltip. Empty string when editing is allowed. */
    denyReason: (key: string | null | undefined) => string;
}

export function buildPermissions(people: Person[], email: string | null): Permissions {
    const person = email
        ? people.find((p) => p.active && p.email && p.email.toLowerCase() === email.toLowerCase()) ?? null
        : null;
    const isAdmin = person?.role === "admin";
    const companies = (person?.companies ?? []).map((c) => normalizeCompany(c)!).filter(Boolean);

    const canEditCompany = (company: string | null): boolean => {
        if (isAdmin) return true;
        if (!company) return false;
        return companies.includes(company);
    };
    const canEditKey = (key: string | null | undefined): boolean => canEditCompany(companyOfKey(key));
    const denyReason = (key: string | null | undefined): string => {
        if (canEditKey(key)) return "";
        if (!person) return "You are not on the approved editors list — ask an admin to add you.";
        if (companies.length === 0) return "No companies are assigned to you — ask an admin.";
        const c = companyOfKey(key);
        return `You are approved for ${companies.join(", ")}, not company ${c ?? "(unknown)"}.`;
    };

    return { person, isAdmin, companies, canEditCompany, canEditKey, denyReason };
}
