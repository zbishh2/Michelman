// Resolving the viewer's email from the host's dataViews.
//
// This lives apart from the grid's dataView on purpose. A scalar measure sitting alongside a
// wide group-by forces the formula engine to materialize every group instead of letting the
// storage engine scan. Measured on the OTIF model via the sibling Order Line Comments visual:
// the identical 20-column query ran in 85ms without the measure and died with "not enough
// memory" after 72s with it — and a constant-string measure behaved the same, so this is about
// group-by width, not USERPRINCIPALNAME. capabilities.json therefore declares a SECOND
// dataViewMapping selecting only the Current User role, so the host issues its own one-row query.
//
// Consequence: options.dataViews is now an array whose order is not guaranteed, so both the grid
// and the identity dataView are located by ROLE rather than by index.

import powerbi from "powerbi-visuals-api";
import DataView = powerbi.DataView;

/** True when this dataView carries the named role in its table metadata. */
function hasRole(dv: DataView | undefined | null, role: string): boolean {
    return !!dv?.table?.columns?.some((c) => c.roles?.[role]);
}

/**
 * The grid dataView: the one bound to the Order Line ID / row-grain roles.
 * Falls back to the first dataView that has table rows, then to dataViews[0], so an
 * unexpected host ordering degrades to the old behaviour rather than a blank visual.
 */
export function pickGridDataView(dataViews: DataView[] | undefined, gridRole: string): DataView | null {
    if (!dataViews?.length) return null;
    return (
        dataViews.find((dv) => hasRole(dv, gridRole)) ??
        dataViews.find((dv) => (dv?.table?.rows?.length ?? 0) > 0) ??
        dataViews[0] ??
        null
    );
}

/**
 * The viewer's email, from whichever dataView carries the currentUser role.
 * Returns null when the field well is empty — callers surface that as "can't identify you"
 * rather than silently dropping to read-only.
 */
export function pickCurrentUserEmail(dataViews: DataView[] | undefined): string | null {
    if (!dataViews?.length) return null;
    for (const dv of dataViews) {
        const idx = dv?.table?.columns?.findIndex((c) => c.roles?.["currentUser"]) ?? -1;
        if (idx < 0) continue;
        for (const row of dv?.table?.rows ?? []) {
            const raw = row[idx];
            if (raw === null || raw === undefined) continue;
            const s = String(raw).trim().toLowerCase();
            if (s) return s;
        }
    }
    return null;
}
