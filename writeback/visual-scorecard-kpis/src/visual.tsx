"use strict";

import * as React from "react";
import { createRoot, Root } from "react-dom/client";
import powerbi from "powerbi-visuals-api";
import { FormattingSettingsService } from "powerbi-visuals-utils-formattingmodel";
import { VisualFormattingSettingsModel } from "./settings";
import { App } from "./App";
import { CSS } from "./styles";
import { setActorEmail } from "./api";

import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import IVisual = powerbi.extensibility.visual.IVisual;

export class Visual implements IVisual {
    private root: Root;
    private container: HTMLDivElement;
    private styleEl: HTMLStyleElement;
    private formattingSettingsService: FormattingSettingsService;
    private formattingSettings: VisualFormattingSettingsModel;
    private updates = 0;

    constructor(options: VisualConstructorOptions) {
        this.formattingSettingsService = new FormattingSettingsService();
        this.styleEl = document.createElement("style");
        this.styleEl.textContent = CSS;
        options.element.appendChild(this.styleEl);
        this.container = document.createElement("div");
        this.container.className = "sck-container";
        options.element.appendChild(this.container);
        this.root = createRoot(this.container);
    }

    /**
     * The visual carries a single optional measure ([Current User]). Everything it
     * renders comes from D1, so update() only reads the identity cell, refreshes the
     * formatting model, and bumps a token so the rows re-pull on report refresh.
     */
    public update(options: VisualUpdateOptions): void {
        // Stamp options.viewport in pixels or nothing scrolls — see
        // ARCHITECTURE.md § Stamp options.viewport. Power BI does not guarantee a
        // definite height on options.element, and every height below is a percentage.
        this.container.style.width = `${Math.max(0, Math.floor(options.viewport.width))}px`;
        this.container.style.height = `${Math.max(0, Math.floor(options.viewport.height))}px`;

        this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(
            VisualFormattingSettingsModel,
            options.dataViews?.[0]
        );

        const single = options.dataViews?.[0]?.single?.value;
        setActorEmail(typeof single === "string" ? single : null);

        const t = this.formattingSettings.tableCard;
        this.root.render(
            <App
                fontSizePt={t.fontSize.value || 10}
                trendHeader={t.trendHeader.value || "Trend (6-Mo)"}
                readOnly={t.readOnly.value}
                refreshToken={++this.updates}
            />
        );
    }

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return this.formattingSettingsService.buildFormattingModel(this.formattingSettings);
    }

    public destroy(): void {
        this.root?.unmount();
    }
}
