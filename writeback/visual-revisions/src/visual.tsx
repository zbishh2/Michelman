"use strict";

import * as React from "react";
import { createRoot, Root } from "react-dom/client";
import powerbi from "powerbi-visuals-api";
import { FormattingSettingsService } from "powerbi-visuals-utils-formattingmodel";
import { IFilter } from "powerbi-models";

import FilterAction = powerbi.FilterAction;
import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import IVisual = powerbi.extensibility.visual.IVisual;
import IVisualHost = powerbi.extensibility.visual.IVisualHost;

import { VisualFormattingSettingsModel } from "./settings";
import { App } from "./App";
import { pickGridDataView, pickCurrentUserEmail } from "./identity";
import { CSS } from "./styles";
import { PersistedSort } from "./types";
import { ColumnFilters, parseColumnFilters, parseColumnOrder, parseSortState, parseWidths } from "./filters";

export class Visual implements IVisual {
    private root: Root;
    private host: IVisualHost;
    private container: HTMLDivElement;
    private styleEl: HTMLStyleElement;
    private formattingSettingsService: FormattingSettingsService;
    private formattingSettings: VisualFormattingSettingsModel;

    constructor(options: VisualConstructorOptions) {
        this.host = options.host;
        this.formattingSettingsService = new FormattingSettingsService();
        this.styleEl = document.createElement("style");
        this.styleEl.textContent = CSS;
        options.element.appendChild(this.styleEl);
        this.container = document.createElement("div");
        this.container.className = "rle-container";
        options.element.appendChild(this.container);
        this.root = createRoot(this.container);
    }

    private persistGeneral = (properties: Record<string, powerbi.DataViewPropertyValue>): void => {
        this.host.persistProperties({
            merge: [{ objectName: "general", selector: null, properties }],
        });
    };

    private persistWidths = (widths: Record<string, number>): void =>
        this.persistGeneral({ columnWidths: JSON.stringify(widths) });
    private persistColumnOrder = (order: string[]): void =>
        this.persistGeneral({ columnOrder: JSON.stringify(order) });
    private persistSort = (sort: PersistedSort | null): void =>
        this.persistGeneral({ sortState: sort ? JSON.stringify(sort) : "" });
    private persistColumnFilters = (filters: ColumnFilters): void =>
        this.persistGeneral({ columnFilters: Object.keys(filters).length ? JSON.stringify(filters) : "" });

    // Push column filters to the report page. We own general.filter write-only:
    // clear the previous set, then merge the new one. A signature dedupe avoids
    // re-pushing on every dataView refresh and breaks the
    // applyJsonFilter -> update() -> push feedback loop (DR's lesson).
    private lastPushedFilters = "";
    private lastAppliedFilters: IFilter[] = [];
    private applyReportFilters = (filters: IFilter[]): void => {
        const sig = JSON.stringify(filters);
        if (sig === this.lastPushedFilters) return;
        this.lastPushedFilters = sig;
        if (this.lastAppliedFilters.length) {
            this.host.applyJsonFilter(this.lastAppliedFilters, "general", "filter", FilterAction.remove);
        }
        if (filters.length) {
            this.host.applyJsonFilter(filters, "general", "filter", FilterAction.merge);
        }
        this.lastAppliedFilters = filters;
    };

    public update(options: VisualUpdateOptions): void {
        // Two dataViews now arrive: the grid and a one-row identity lookup (see identity.ts).
        // Both are located by role — the host does not promise an order.
        const dv = pickGridDataView(options.dataViews, "revisionKey");
        const currentUserEmail = pickCurrentUserEmail(options.dataViews);
        this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(
            VisualFormattingSettingsModel, dv
        );
        const t = this.formattingSettings.titleCard;
        const title = { show: t.show.value, text: t.titleText.value, fontSize: t.fontSize.value, color: t.fontColor.value.value };
        const tableFontSize = this.formattingSettings.tableCard.fontSize.value;
        const editablePosition = this.formattingSettings.tableCard.editablePosition.value;
        const freezeColumns = this.formattingSettings.tableCard.freezeColumns.value;
        const generalObj = (dv?.metadata?.objects as { general?: { columnWidths?: unknown; columnOrder?: unknown; sortState?: unknown; columnFilters?: unknown } } | undefined)?.general;
        const initialWidths = parseWidths(generalObj?.columnWidths);
        const initialColumnOrder = parseColumnOrder(generalObj?.columnOrder);
        const initialSort = parseSortState(generalObj?.sortState);
        const initialColumnFilters = parseColumnFilters(generalObj?.columnFilters);
        try {
            this.root.render(
                <App
                    dataView={dv ?? null}
                    currentUserEmail={currentUserEmail}
                    title={title}
                    tableFontSize={tableFontSize}
                    editablePosition={editablePosition}
                    freezeColumns={freezeColumns}
                    initialWidths={initialWidths}
                    initialColumnOrder={initialColumnOrder}
                    initialSort={initialSort}
                    initialColumnFilters={initialColumnFilters}
                    onPersistWidths={this.persistWidths}
                    onPersistColumnOrder={this.persistColumnOrder}
                    onPersistSort={this.persistSort}
                    onPersistColumnFilters={this.persistColumnFilters}
                    onApplyReportFilters={this.applyReportFilters}
                />
            );
        } catch (err) {
            console.error("Revision Log Editor render error:", err);
            this.root.render(<div className="rle-empty">Visual error: {String(err)}</div>);
        }
    }

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return this.formattingSettingsService.buildFormattingModel(this.formattingSettings);
    }

    public destroy(): void {
        this.root.unmount();
    }
}
