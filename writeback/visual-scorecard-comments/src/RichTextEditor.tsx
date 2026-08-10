// WYSIWYG composer / editor for board posts, built on Lexical (Meta's editor framework).
//
// Replaces a hand-rolled document.execCommand editor. The reason is maintenance, not features:
// execCommand works, but every rough edge in it — undo granularity, list splitting and outdent,
// selection across nested inline tags, IME composition, paste normalisation — is a bug someone
// would have had to find in production and fix here by hand. Lexical owns that surface.
//
// WHAT DID NOT CHANGE: storage is still markdown-ish plain text in `board_comments.body`, so
// exports, `comment_history`, and (if this is ever ported to line comments) the
// LineComments[Latest Comment] model column all keep reading as text. Lexical is the editing
// layer only; @lexical/markdown does the conversion at the boundary.
//
// The read-only thread does NOT use Lexical — richtext.tsx renders posts as plain React nodes.
// Mounting an editor per post to display it would be wasteful, and the display path stays free of
// any innerHTML.

import * as React from "react";
import { LexicalComposer } from "@lexical/react/LexicalComposer";
import { RichTextPlugin } from "@lexical/react/LexicalRichTextPlugin";
import { ContentEditable } from "@lexical/react/LexicalContentEditable";
import { HistoryPlugin } from "@lexical/react/LexicalHistoryPlugin";
import { ListPlugin } from "@lexical/react/LexicalListPlugin";
import { MarkdownShortcutPlugin } from "@lexical/react/LexicalMarkdownShortcutPlugin";
import { LexicalErrorBoundary } from "@lexical/react/LexicalErrorBoundary";
import { useLexicalComposerContext } from "@lexical/react/LexicalComposerContext";
import { useLexicalIsTextContentEmpty } from "@lexical/react/useLexicalIsTextContentEmpty";
import {
    ListNode,
    ListItemNode,
    $isListItemNode,
    INSERT_UNORDERED_LIST_COMMAND,
    INSERT_ORDERED_LIST_COMMAND,
} from "@lexical/list";
import {
    $convertFromMarkdownString,
    $convertToMarkdownString,
    BOLD_ITALIC_STAR,
    BOLD_STAR,
    ITALIC_STAR,
    STRIKETHROUGH,
    INLINE_CODE,
    UNORDERED_LIST,
    ORDERED_LIST,
    Transformer,
} from "@lexical/markdown";
import {
    $getRoot,
    $getSelection,
    $isRangeSelection,
    FORMAT_TEXT_COMMAND,
    KEY_ENTER_COMMAND,
    KEY_ESCAPE_COMMAND,
    COMMAND_PRIORITY_HIGH,
    TextFormatType,
    LexicalEditor,
} from "lexical";

/**
 * The markdown dialect, curated rather than Lexical's full TRANSFORMERS list.
 *
 * Star-only emphasis: the underscore transformers are deliberately omitted so `order_line_id`,
 * `person_key`, `reason_dim` and `IM_HoursLogged` survive a round trip instead of coming back as
 * `order line id` with the middle italicised. Headings, quotes, code blocks and links are left out
 * too — the panel is ~150px tall and authors type two sentences into it.
 *
 * Element transformers precede text-format ones, matching how Lexical composes TRANSFORMERS.
 */
const MD: Transformer[] = [
    UNORDERED_LIST,
    ORDERED_LIST,
    BOLD_ITALIC_STAR,
    BOLD_STAR,
    ITALIC_STAR,
    STRIKETHROUGH,
    INLINE_CODE,
];

/**
 * Lexical backslash-escapes every `*`, `_`, backtick and `~` it finds in plain text on export
 * (MarkdownExport: `output.replace(/([*_`~])/g, '\\$1')`). Left alone, `order_line_id` is stored
 * as `order\_line\_id` — and that backslash is real: it goes into D1, into CSV exports, into
 * `comment_history`, and into LineComments[Latest Comment] if this is ever ported to line
 * comments. Our dialect has no escaping layer by design, and dropping the underscore transformers
 * already makes `_` inert on the way back in, so undoing the escapes is the exact inverse and
 * costs nothing. Verified by md-roundtrip.test.mjs.
 */
const UNESCAPE = /\\([*_`~\\])/g;

/**
 * `shouldPreserveNewLines` (the third argument, both directions) keeps a single newline as a
 * single newline. Without it Lexical round-trips "Actions:\n- chase Ivan" into
 * "Actions:\n\n- chase Ivan", which the display renderer reads as a deliberate blank line and
 * shows as a gap that grows every time someone edits the post.
 */
function readMarkdown(): string {
    return $convertToMarkdownString(MD, undefined, true).replace(UNESCAPE, "$1");
}

export interface RichTextEditorHandle {
    /** Current contents as markdown. */
    getMarkdown(): string;
    /** Reset to empty (after a successful post). */
    clear(): void;
    focus(): void;
}

export interface RichTextEditorProps {
    /** Markdown to seed the surface with. Read once on mount — later changes are ignored. */
    initialValue?: string;
    placeholder?: string;
    autoFocus?: boolean;
    className?: string;
    /** Enter (without Shift), except inside a list where Enter makes the next bullet. */
    onSubmit?: () => void;
    onEscape?: () => void;
    /** Fires when the surface transitions between empty and non-empty, to gate the Post button. */
    onEmptyChange?: (empty: boolean) => void;
    /** Rendered at the right of the toolbar — region picker, Post / Save / Cancel. */
    children?: React.ReactNode;
}

// ─── Toolbar ──────────────────────────────────────────────────────────────────

type Fmt = Extract<TextFormatType, "bold" | "italic" | "strikethrough">;

const FORMAT_BUTTONS: { fmt: Fmt; label: string; title: string; cls: string }[] = [
    { fmt: "bold", label: "B", title: "Bold  (Ctrl+B)", cls: "scb-tb-bold" },
    { fmt: "italic", label: "I", title: "Italic  (Ctrl+I)", cls: "scb-tb-italic" },
    { fmt: "strikethrough", label: "S", title: "Strikethrough", cls: "scb-tb-strike" },
];

const Toolbar: React.FC = () => {
    const [editor] = useLexicalComposerContext();
    const [active, setActive] = React.useState<Record<string, boolean>>({});

    // Lexical reports selection state through update listeners, so the buttons stay in sync with
    // arrow-key and click moves, not just with typing.
    React.useEffect(() => {
        return editor.registerUpdateListener(({ editorState }) => {
            editorState.read(() => {
                const sel = $getSelection();
                if (!$isRangeSelection(sel)) return;
                const next: Record<string, boolean> = {};
                for (const b of FORMAT_BUTTONS) next[b.fmt] = sel.hasFormat(b.fmt);
                setActive((prev) =>
                    FORMAT_BUTTONS.every((b) => prev[b.fmt] === next[b.fmt]) ? prev : next
                );
            });
        });
    }, [editor]);

    const btn = (key: string, label: string, title: string, cls: string, on: boolean, run: () => void) => (
        <button
            type="button"
            key={key}
            className={"scb-tb " + cls + (on ? " scb-tb-on" : "")}
            title={title}
            aria-pressed={on}
            // Keep focus (and the selection) in the editor when the button is clicked.
            onMouseDown={(e) => e.preventDefault()}
            onClick={run}
        >{label}</button>
    );

    return (
        <>
            {FORMAT_BUTTONS.map((b) =>
                btn(b.fmt, b.label, b.title, b.cls, !!active[b.fmt],
                    () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, b.fmt))
            )}
            {btn("ul", "•", "Bulleted list", "", false,
                () => editor.dispatchCommand(INSERT_UNORDERED_LIST_COMMAND, undefined))}
            {btn("ol", "1.", "Numbered list", "scb-tb-ol", false,
                () => editor.dispatchCommand(INSERT_ORDERED_LIST_COMMAND, undefined))}
        </>
    );
};

// ─── Behaviour plugins ────────────────────────────────────────────────────────

/** Enter submits; Shift+Enter breaks the line; inside a list Enter makes the next bullet. */
const KeysPlugin: React.FC<{ onSubmit?: () => void; onEscape?: () => void }> = ({ onSubmit, onEscape }) => {
    const [editor] = useLexicalComposerContext();
    React.useEffect(() => {
        const offEnter = editor.registerCommand<KeyboardEvent | null>(
            KEY_ENTER_COMMAND,
            (event) => {
                if (event?.shiftKey) return false;
                const sel = $getSelection();
                if ($isRangeSelection(sel)) {
                    // Walk up from the caret: in a list, Enter belongs to the list plugin.
                    let node = sel.anchor.getNode() as import("lexical").LexicalNode | null;
                    while (node) {
                        if ($isListItemNode(node)) return false;
                        node = node.getParent();
                    }
                }
                if (!onSubmit) return false;
                event?.preventDefault();
                onSubmit();
                return true;
            },
            COMMAND_PRIORITY_HIGH
        );
        const offEsc = editor.registerCommand<KeyboardEvent | null>(
            KEY_ESCAPE_COMMAND,
            () => { if (!onEscape) return false; onEscape(); return true; },
            COMMAND_PRIORITY_HIGH
        );
        return () => { offEnter(); offEsc(); };
    }, [editor, onSubmit, onEscape]);
    return null;
};

/** Mirrors emptiness out to the caller so the Post button can be disabled. */
const EmptyPlugin: React.FC<{ onEmptyChange?: (empty: boolean) => void }> = ({ onEmptyChange }) => {
    const [editor] = useLexicalComposerContext();
    const empty = useLexicalIsTextContentEmpty(editor, true);
    React.useEffect(() => { onEmptyChange?.(empty); }, [empty, onEmptyChange]);
    return null;
};

/** Publishes the imperative handle. Must live inside the composer to reach the editor. */
const HandlePlugin = React.forwardRef<RichTextEditorHandle, { autoFocus?: boolean }>(({ autoFocus }, ref) => {
    const [editor] = useLexicalComposerContext();

    React.useImperativeHandle(ref, () => ({
        getMarkdown: () => editor.getEditorState().read(readMarkdown),
        clear: () => {
            editor.update(() => { $getRoot().clear(); });
        },
        focus: () => editor.focus(),
    }), [editor]);

    React.useEffect(() => {
        if (!autoFocus) return;
        // Caret to the end, so editing an existing post continues rather than prepends.
        editor.focus(() => {
            editor.update(() => { $getRoot().selectEnd(); });
        });
    }, [editor, autoFocus]);

    return null;
});
HandlePlugin.displayName = "HandlePlugin";

// ─── Editor ───────────────────────────────────────────────────────────────────

/** Class names Lexical stamps on the nodes it creates, so styles.ts can target them. */
const THEME = {
    paragraph: "scb-p",
    text: {
        bold: "scb-b",
        italic: "scb-i",
        strikethrough: "scb-s",
        code: "scb-c",
    },
    list: {
        ul: "scb-ul",
        ol: "scb-ol",
        listitem: "scb-li",
    },
};

export const RichTextEditor = React.forwardRef<RichTextEditorHandle, RichTextEditorProps>((props, ref) => {
    const { initialValue = "", placeholder, autoFocus, className, onSubmit, onEscape, onEmptyChange } = props;

    // Read once. The caller re-mounts (via `key`) when it wants a different comment loaded;
    // re-seeding mid-edit would wipe whatever the author had typed.
    const initialConfig = React.useMemo(() => ({
        namespace: "obc",
        theme: THEME,
        nodes: [ListNode, ListItemNode],
        editorState: initialValue
            // Third arg is the container node, fourth is shouldPreserveNewLines — it must match
            // the export side or a saved post gains a blank line on every edit.
            ? () => $convertFromMarkdownString(initialValue, MD, undefined, true)
            : undefined,
        // A malformed stored body must not blank the whole visual; log and carry on with an
        // empty surface rather than letting the error escape into the React tree.
        onError: (e: Error) => { console.error("[obc] editor", e); },
        // eslint-disable-next-line
    }), []);

    return (
        <div className={"scb-rte" + (className ? " " + className : "")}>
            <LexicalComposer initialConfig={initialConfig}>
                <div className="scb-toolbar">
                    <Toolbar />
                    {props.children}
                </div>
                {/* Lexical renders the placeholder as a SIBLING of the editable div, positioned
                    absolutely. It therefore anchors to the nearest positioned ancestor — which,
                    without this wrapper, was the whole component including the toolbar, so the
                    placeholder sat on top of the B / I / S buttons instead of in the text box.
                    The wrapper scopes it to the editable area. */}
                <div className="scb-rte-body">
                    <RichTextPlugin
                        contentEditable={
                            <ContentEditable
                                className="scb-surface"
                                aria-label={placeholder}
                                aria-placeholder={placeholder ?? ""}
                                placeholder={<div className="scb-placeholder">{placeholder}</div>}
                            />
                        }
                        ErrorBoundary={LexicalErrorBoundary}
                    />
                </div>
                <HistoryPlugin />
                <ListPlugin />
                {/* Typing "**x**" or "- " converts as you go, for anyone who knows the syntax.
                    Nobody has to: the toolbar and Ctrl+B/I do the same thing. */}
                <MarkdownShortcutPlugin transformers={MD} />
                <KeysPlugin onSubmit={onSubmit} onEscape={onEscape} />
                <EmptyPlugin onEmptyChange={onEmptyChange} />
                <HandlePlugin ref={ref} autoFocus={autoFocus} />
            </LexicalComposer>
        </div>
    );
});

RichTextEditor.displayName = "RichTextEditor";

/** Re-exported so callers can type a ref without importing the editor internals. */
export type { LexicalEditor };
