"use strict";

import { formattingSettings } from "powerbi-visuals-utils-formattingmodel";
import FormattingSettingsModel = formattingSettings.Model;

class TitleCard extends formattingSettings.SimpleCard {
    show = new formattingSettings.ToggleSwitch({ name: "show", displayName: "Show", value: true });
    titleText = new formattingSettings.TextInput({
        name: "titleText",
        displayName: "Title text",
        value: "Actions & Comments",
        placeholder: "",
    });
    fontSize = new formattingSettings.NumUpDown({ name: "fontSize", displayName: "Font size", value: 13 });
    fontColor = new formattingSettings.ColorPicker({
        name: "fontColor",
        displayName: "Color",
        value: { value: "#222222" },
    });

    name = "title";
    displayName = "Title";
    slices: formattingSettings.Slice[] = [this.show, this.titleText, this.fontSize, this.fontColor];
}

class BoardCard extends formattingSettings.SimpleCard {
    boardKey = new formattingSettings.TextInput({
        name: "boardKey",
        displayName: "Board key",
        description:
            "Namespaces the thread. Two visuals sharing a key share their posts; change it to give another page its own board.",
        value: "summary-shipped-as-promised",
        placeholder: "summary-shipped-as-promised",
    });
    placeholder = new formattingSettings.TextInput({
        name: "placeholder",
        displayName: "Composer prompt",
        value: "Add an action or comment…",
        placeholder: "",
    });
    readOnly = new formattingSettings.ToggleSwitch({
        name: "readOnly",
        displayName: "Read only",
        value: false,
    });

    name = "board";
    displayName = "Board";
    slices: formattingSettings.Slice[] = [this.boardKey, this.placeholder, this.readOnly];
}

class TextCard extends formattingSettings.SimpleCard {
    fontSize = new formattingSettings.NumUpDown({ name: "fontSize", displayName: "Font size", value: 12 });

    name = "text";
    displayName = "Text";
    slices: formattingSettings.Slice[] = [this.fontSize];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    titleCard = new TitleCard();
    boardCard = new BoardCard();
    textCard = new TextCard();
    cards = [this.titleCard, this.boardCard, this.textCard];
}
