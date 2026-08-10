"use strict";

import { formattingSettings } from "powerbi-visuals-utils-formattingmodel";
import FormattingSettingsModel = formattingSettings.Model;

class TableCard extends formattingSettings.SimpleCard {
    // 10pt to match the page's native tableEx tables; the header and cells scale together.
    fontSize = new formattingSettings.NumUpDown({ name: "fontSize", displayName: "Font size (pt)", value: 10 });
    trendHeader = new formattingSettings.TextInput({
        name: "trendHeader",
        displayName: "Trend header",
        description: "Header text for the trend column. Kept as a setting so a rename never needs a repackage.",
        value: "Trend (6-Mo)",
        placeholder: "Trend (6-Mo)",
    });
    readOnly = new formattingSettings.ToggleSwitch({
        name: "readOnly",
        displayName: "Read only",
        description: "Hides the per-row edit affordance. The Worker enforces the editor/admin gate regardless.",
        value: false,
    });

    name = "table";
    displayName = "Table";
    slices: formattingSettings.Slice[] = [this.fontSize, this.trendHeader, this.readOnly];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    tableCard = new TableCard();
    cards = [this.tableCard];
}
