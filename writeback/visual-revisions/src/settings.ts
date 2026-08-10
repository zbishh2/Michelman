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
        value: "Revision Log",
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

    name = "title";
    displayName = "Title";
    slices: formattingSettings.Slice[] = [this.show, this.titleText, this.fontSize, this.fontColor];
}

class TableCard extends formattingSettings.SimpleCard {
    fontSize = new formattingSettings.NumUpDown({
        name: "fontSize",
        displayName: "Font size",
        value: 12,
    });

    editablePosition = new formattingSettings.NumUpDown({
        name: "editablePosition",
        displayName: "Editable columns position",
        description: "Slot the Override Reason / Note columns at this 1-based position among your data columns. 1 = before everything; N+1 = after everything.",
        value: 1,
    });

    freezeColumns = new formattingSettings.NumUpDown({
        name: "freezeColumns",
        displayName: "Freeze columns",
        description: "Keep this many leftmost columns pinned in place while scrolling horizontally. 0 = freeze none.",
        value: 3,
    });

    name = "table";
    displayName = "Table";
    slices: formattingSettings.Slice[] = [this.fontSize, this.editablePosition, this.freezeColumns];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    titleCard = new TitleCard();
    tableCard = new TableCard();
    cards = [this.titleCard, this.tableCard];
}
