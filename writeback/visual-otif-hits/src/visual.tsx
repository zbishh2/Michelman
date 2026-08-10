"use strict";

import * as React from "react";
import { createRoot, Root } from "react-dom/client";
import powerbi from "powerbi-visuals-api";
import { FormattingSettingsService } from "powerbi-visuals-utils-formattingmodel";
import { VisualFormattingSettingsModel } from "./settings";
import { App } from "./App";
import { CSS } from "./styles";
import { parseWidths, parseColumnOrder, parseSortState } from "./util";
import { ColumnFilters, parseColumnFilters } from "./filters";

import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import IVisual = powerbi.extensibility.visual.IVisual;
import IVisualHost = powerbi.extensibility.visual.IVisualHost;

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
        this.container.className = "olc-container";
        options.element.appendChild(this.container);
        this.root = createRoot(this.container);
    }

    private persistWidths = (widths: Record<string, number>): void => {
        this.host.persistProperties({
            merge: [{ objectName: "general", selector: null, properties: { columnWidths: JSON.stringify(widths) } }],
        });
    };

    private persistColumnOrder = (order: string[]): void => {
        this.host.persistProperties({
            merge: [{ objectName: "general", selector: null, properties: { columnOrder: JSON.stringify(order) } }],
        });
    };

    private persistSort = (sort: { key: string; direction: "asc" | "desc" } | null): void => {
        this.host.persistProperties({
            merge: [{ objectName: "general", selector: null, properties: { sortState: sort ? JSON.stringify(sort) : "" } }],
        });
    };

    private persistColumnFilters = (filters: ColumnFilters): void => {
        this.host.persistProperties({
            merge: [{ objectName: "general", selector: null, properties: { columnFilters: Object.keys(filters).length ? JSON.stringify(filters) : "" } }],
        });
    };

    public update(options: VisualUpdateOptions): void {
        const dv = options.dataViews && options.dataViews[0];
        this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(VisualFormattingSettingsModel, dv);
        const t = this.formattingSettings.titleCard;
        const title = { show: t.show.value, text: t.titleText.value, fontSize: t.fontSize.value, color: t.fontColor.value.value };
        const tableFontSize = this.formattingSettings.tableCard.fontSize.value;
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
                    title={title}
                    tableFontSize={tableFontSize}
                    freezeColumns={freezeColumns}
                    initialWidths={initialWidths}
                    initialColumnOrder={initialColumnOrder}
                    initialSort={initialSort}
                    initialColumnFilters={initialColumnFilters}
                    onPersistWidths={this.persistWidths}
                    onPersistColumnOrder={this.persistColumnOrder}
                    onPersistSort={this.persistSort}
                    onPersistColumnFilters={this.persistColumnFilters}
                />
            );
        } catch (err) {
            console.error("OTIF Hit Codes visual render error:", err);
            this.root.render(<div className="olc-empty">Visual error: {String(err)}</div>);
        }
    }

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return this.formattingSettingsService.buildFormattingModel(this.formattingSettings);
    }

    public destroy(): void {
        this.root.unmount();
    }
}
