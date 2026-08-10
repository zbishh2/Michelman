"use strict";

import { formattingSettings } from "powerbi-visuals-utils-formattingmodel";
import FormattingSettingsModel = formattingSettings.Model;

class TitleCard extends formattingSettings.SimpleCard {
    show = new formattingSettings.ToggleSwitch({ name: "show", displayName: "Show", value: true });
    titleText = new formattingSettings.TextInput({
        name: "titleText",
        displayName: "Title text",
        value: "Comments",
        placeholder: "",
    });
    fontSize = new formattingSettings.NumUpDown({ name: "fontSize", displayName: "Font size", value: 13 });
    fontColor = new formattingSettings.ColorPicker({
        name: "fontColor",
        displayName: "Color",
        value: { value: "#221C35" },
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
            "Namespaces the thread in the shared board_comments table. Two visuals sharing a key share their posts; change it to give another page its own feed. NOTE: this visual defaults to the Executive Scorecard's key, not the OTIF board's.",
        value: "exec-scorecard-people",
        placeholder: "exec-scorecard-people",
    });
    placeholder = new formattingSettings.TextInput({
        name: "placeholder",
        displayName: "Composer prompt",
        description: "Ghost text inside the dialog's editor, not on the page.",
        value: "Write a comment…",
        placeholder: "",
    });
    addLabel = new formattingSettings.TextInput({
        name: "addLabel",
        displayName: "Add button text",
        value: "Add comment",
        placeholder: "Add comment",
    });
    readOnly = new formattingSettings.ToggleSwitch({
        name: "readOnly",
        displayName: "Read only",
        description: "Hides the Add button and the per-post Edit / Delete actions.",
        value: false,
    });

    name = "board";
    displayName = "Board";
    slices: formattingSettings.Slice[] = [this.boardKey, this.placeholder, this.addLabel, this.readOnly];
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
