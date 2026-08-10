// Rich text for the Actions & Comments thread (Ivan's request).
//
// TWO LAYERS, AND THE SPLIT IS THE WHOLE DESIGN:
//
//   storage  — markdown-ish PLAIN TEXT in `board_comments.body`, exactly as it always was.
//   editing  — a real WYSIWYG surface. The author sees bold text, never "**".
//
// The editor never shows markers and never asks anyone to learn syntax; markdown is purely the
// wire format, produced on save and parsed back on edit. Keeping it that way matters because the
// column is read from outside this visual:
//   1. CSV exports, D1 queries and `comment_history` still get something legible. "**urgent**"
//      degrades gracefully; a blob of HTML does not.
//   2. If this is ported to ORDER LINE comments, that body folds into the semantic model as
//      LineComments[Latest Comment] and renders in ordinary Power BI tables and tooltips, which
//      show text literally.
//
// DISPLAY PRODUCES REACT NODES, NEVER AN HTML STRING — no dangerouslySetInnerHTML anywhere.
// React escapes text nodes by construction, so a post containing "<script>" is shown, not run.
// (The editor builds its DOM with createElement/createTextNode for the same reason: Power BI
// visual certification forbids innerHTML, and `pbiviz package` lints for it.)
//
// This file is the DISPLAY half only. Editing is Lexical (see RichTextEditor.tsx), and the
// markdown dialect it reads and writes is the curated `MD` transformer list there. Keep the two in
// step: star-only emphasis, no headings/quotes/links, bullets and numbered lists. The display side
// stays hand-rolled on purpose — mounting a Lexical editor per post just to show it would be
// wasteful, and rendering React nodes keeps the read path free of innerHTML.

import * as React from "react";

export type TokKind = "text" | "bold" | "italic" | "strike" | "code" | "url";

export interface Tok {
    kind: TokKind;
    /** Literal text for "text" / "url" / "code"; the raw inner source for the nesting kinds. */
    text: string;
    /** Parsed children for bold / italic / strike. Absent for leaves. */
    children?: Tok[];
}

// One pass, longest-marker-first so "**bold**" is not read as two empty italics. Each
// alternative is non-greedy and forbids a newline, keeping a stray "*" from swallowing the rest
// of the thread. Bare URLs are linkified last.
//
// "_italic_" is deliberately NOT supported. Suppressing intraword underscores the way real
// markdown does needs a lookbehind; without one "RFRV_code_name" renders as "RFRVcodename" with
// the middle italicised. This domain is wall-to-wall underscore identifiers — order_line_id,
// person_key, reason_dim, IM_HoursLogged — so an underscore is likelier to be a field name than
// emphasis. Nobody types markers by hand any more anyway; the toolbar does it.
const INLINE = new RegExp(
    [
        "\\*\\*(?![\\s*])((?:[^*\\n]|\\*(?!\\*))+?)\\*\\*", // **bold**
        "~~(?![\\s~])([^~\\n]+?)~~",                        // ~~strike~~
        "`([^`\\n]+?)`",                                    // `code`
        "\\*(?![\\s*])([^*\\n]+?)\\*",                      // *italic*
        "(https?://[^\\s<>()]+[^\\s<>().,;:!?'\"])",        // bare URL
    ].join("|"),
    "g"
);

// Bold and italic nest ("**bold with *emphasis* inside**"). The cap is a cheap guarantee
// against a pathological input recursing without end.
const MAX_DEPTH = 4;

/** Split one line of source into inline tokens. */
export function tokenize(text: string, depth = 0): Tok[] {
    const out: Tok[] = [];
    let last = 0;
    let m: RegExpExecArray | null;
    // A fresh RegExp per call: `INLINE` is global and stateful, and tokenize() recurses, so a
    // shared lastIndex would have inner calls corrupting the outer scan mid-string.
    const re = new RegExp(INLINE.source, "g");

    while ((m = re.exec(text)) !== null) {
        if (m.index > last) out.push({ kind: "text", text: text.slice(last, m.index) });
        const [, bold, strike, code, italic, url] = m;

        if (code !== undefined) {
            // Code is literal by definition — never recurse into it.
            out.push({ kind: "code", text: code });
        } else if (bold !== undefined) {
            out.push({ kind: "bold", text: bold, children: kids(bold, depth) });
        } else if (strike !== undefined) {
            out.push({ kind: "strike", text: strike, children: kids(strike, depth) });
        } else if (italic !== undefined) {
            out.push({ kind: "italic", text: italic, children: kids(italic, depth) });
        } else if (url !== undefined) {
            out.push({ kind: "url", text: url });
        }
        last = m.index + m[0].length;
    }
    if (last < text.length) out.push({ kind: "text", text: text.slice(last) });
    return out;
}

function kids(text: string, depth: number): Tok[] {
    return depth >= MAX_DEPTH ? [{ kind: "text", text }] : tokenize(text, depth + 1);
}

export type Block =
    | { kind: "p"; toks: Tok[] }
    | { kind: "blank" }
    | { kind: "ul" | "ol"; items: Tok[][] };

const BULLET = /^\s*[-*]\s+(.*)$/;
const NUMBER = /^\s*\d+[.)]\s+(.*)$/;

/**
 * Split a stored body into blocks.
 *
 * Deliberately minimal: consecutive "- " lines become one list, consecutive "1. " lines another,
 * everything else is a line. No headings, quotes or tables — the panel is ~150px tall and authors
 * type two sentences into it.
 */
export function parseBlocks(body: string): Block[] {
    const lines = (body ?? "").split(/\r?\n/);
    const blocks: Block[] = [];
    let list: { kind: "ul" | "ol"; items: Tok[][] } | null = null;

    const flush = () => { if (list) { blocks.push(list); list = null; } };

    for (const line of lines) {
        const b = BULLET.exec(line);
        const n = b ? null : NUMBER.exec(line);
        if (b || n) {
            const kind = b ? "ul" : "ol";
            if (!list || list.kind !== kind) { flush(); list = { kind, items: [] }; }
            list.items.push(tokenize(b ? b[1] : n![1]));
            continue;
        }
        flush();
        blocks.push(line.trim() === "" ? { kind: "blank" } : { kind: "p", toks: tokenize(line) });
    }
    flush();
    return blocks;
}

// ─── Display rendering (React nodes) ──────────────────────────────────────────

export interface RichTextOptions {
    /** Power BI sandboxes the visual's iframe, so a plain <a href> does nothing. The host's
     *  launchUrl is the only way to actually open a link; without it, links render as text. */
    launchUrl?: (url: string) => void;
}

function toNodes(toks: Tok[], opts: RichTextOptions, keyBase: string): React.ReactNode[] {
    return toks.map((t, i) => {
        const key = `${keyBase}-${i}`;
        switch (t.kind) {
            case "text": return t.text;
            case "code": return <code className="obc-code" key={key}>{t.text}</code>;
            case "bold": return <strong key={key}>{toNodes(t.children ?? [], opts, key)}</strong>;
            case "italic": return <em key={key}>{toNodes(t.children ?? [], opts, key)}</em>;
            case "strike": return <s key={key}>{toNodes(t.children ?? [], opts, key)}</s>;
            case "url": return opts.launchUrl
                ? <a
                    className="obc-a"
                    key={key}
                    href={t.text}
                    onClick={(e) => { e.preventDefault(); opts.launchUrl!(t.text); }}
                >{t.text}</a>
                : <span className="obc-a-plain" key={key}>{t.text}</span>;
        }
    });
}

/** Render a stored comment body for the read-only thread. */
export function renderRich(body: string, opts: RichTextOptions = {}): React.ReactNode {
    return parseBlocks(body).map((b, i) => {
        switch (b.kind) {
            case "blank": return <div className="obc-gap" key={i} />;
            case "p": return <div className="obc-line" key={i}>{toNodes(b.toks, opts, String(i))}</div>;
            case "ul": return (
                <ul className="obc-list" key={i}>
                    {b.items.map((it, j) => <li key={j}>{toNodes(it, opts, `${i}-${j}`)}</li>)}
                </ul>
            );
            case "ol": return (
                <ol className="obc-list" key={i}>
                    {b.items.map((it, j) => <li key={j}>{toNodes(it, opts, `${i}-${j}`)}</li>)}
                </ol>
            );
        }
    });
}
