"use strict";

import { formattingSettings } from "powerbi-visuals-utils-formattingmodel";
import FormattingSettingsModel = formattingSettings.Model;

class TitleCard extends formattingSettings.SimpleCard {
    show = new formattingSettings.ToggleSwitch({
        name: "show",
        displayName: "Show",
        value: true,
    });

    titleText = new formattingSettings.TextInput({
        name: "titleText",
        displayName: "Title text",
        value: "OTIF Hit Codes",
        placeholder: "",
    });

    fontSize = new formattingSettings.NumUpDown({
        name: "fontSize",
        displayName: "Font size",
        value: 14,
    });

    fontColor = new formattingSettings.ColorPicker({
        name: "fontColor",
        displayName: "Color",
        value: { value: "#222222" },
    });

    name: string = "title";
    displayName: string = "Title";
    slices: formattingSettings.Slice[] = [this.show, this.titleText, this.fontSize, this.fontColor];
}

class TableCard extends formattingSettings.SimpleCard {
    fontSize = new formattingSettings.NumUpDown({
        name: "fontSize",
        displayName: "Font size",
        value: 12,
    });

    freezeColumns = new formattingSettings.NumUpDown({
        name: "freezeColumns",
        displayName: "Freeze columns",
        description: "Keep this many leftmost columns pinned in place while scrolling horizontally. 0 = freeze none.",
        value: 2,
    });

    name: string = "table";
    displayName: string = "Table";
    slices: formattingSettings.Slice[] = [this.fontSize, this.freezeColumns];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    titleCard = new TitleCard();
    tableCard = new TableCard();
    cards = [this.titleCard, this.tableCard];
}
