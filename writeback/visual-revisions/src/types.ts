// Shared grid types + the key that identifies the editable override column
// (Revision Reason). Editable-column keys are prefixed "edit:" so they never
// collide with real model-column keys ("data:...").

import powerbi from "powerbi-visuals-api";
import DataViewMetadataColumn = powerbi.DataViewMetadataColumn;

export const KEY_REASON = "edit:revisionReason";

export type EditField = "revisionReason";

// A real (model) display column resolved from the dataView.
export interface ColSpec {
    metaIndex: number;          // column index in metadata.columns / row tuple
    column: DataViewMetadataColumn;
    isRevisionKey: boolean;
    projectionIndex: number;
}

export interface PersistedSort {
    key: string;
    direction: "asc" | "desc";
}

export interface SortState {
    key: string;
    direction: "asc" | "desc";
    // Data-column sort: metaIndex/column are set. Editable-column sort: editField is set.
    metaIndex: number;
    column: DataViewMetadataColumn | null;
    editField: EditField | null;
}
