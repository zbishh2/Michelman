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
    /** Only way to open a link from inside the sandboxed iframe; a plain <a href> is inert. */
    private launchUrl: (url: string) => void;

    constructor(options: VisualConstructorOptions) {
        this.formattingSettingsService = new FormattingSettingsService();
        this.launchUrl = (url: string) => options.host.launchUrl(url);
        this.styleEl = document.createElement("style");
        this.styleEl.textContent = CSS;
        options.element.appendChild(this.styleEl);
        this.container = document.createElement("div");
        this.container.className = "scb-container";
        options.element.appendChild(this.container);
        this.root = createRoot(this.container);
    }

    /**
     * The visual carries a single optional measure ([Current User]). Everything else it
     * renders comes from D1, so update() only needs to read the identity cell, refresh the
     * formatting model, and bump a token so the thread re-pulls on report refresh.
     */
    public update(options: VisualUpdateOptions): void {
        // THE SCROLL FIX, and it has to be here rather than in CSS.
        //
        // Every height below this point is a percentage: .scb-container is height:100%, .scb-root
        // is height:100%, and the thread is a flex child of that. Power BI does NOT guarantee a
        // definite height on options.element, and a percentage height against an auto-height
        // parent resolves to auto. When that happens the whole chain collapses to CONTENT height:
        // .scb-root grows to fit every post, .scb-thread is therefore never smaller than its
        // contents, overflow-y:auto has nothing to overflow, and the posts past the bottom edge
        // are simply clipped by the iframe with no scrollbar. min-height:0 on the thread is
        // necessary but useless on its own — it only matters once the parent is definite.
        //
        // options.viewport is the host's authoritative size for the visual, so stamping it in
        // pixels makes the root definite unconditionally and every percentage below resolves.
        this.container.style.width = `${Math.max(0, Math.floor(options.viewport.width))}px`;
        this.container.style.height = `${Math.max(0, Math.floor(options.viewport.height))}px`;

        this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(
            VisualFormattingSettingsModel,
            options.dataViews?.[0]
        );

        const single = options.dataViews?.[0]?.single?.value;
        setActorEmail(typeof single === "string" ? single : null);

        const t = this.formattingSettings.titleCard;
        const b = this.formattingSettings.boardCard;

        this.root.render(
            <App
                boardKey={(b.boardKey.value || "exec-scorecard-people").trim()}
                title={t.titleText.value || "Comments"}
                showTitle={t.show.value}
                titleFontSize={t.fontSize.value}
                titleColor={t.fontColor.value.value}
                fontSize={this.formattingSettings.textCard.fontSize.value}
                placeholder={b.placeholder.value || "Write a comment…"}
                addLabel={b.addLabel.value || "Add comment"}
                readOnly={b.readOnly.value}
                refreshToken={++this.updates}
                launchUrl={this.launchUrl}
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
