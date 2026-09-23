pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backend for the SUPER+I quick-question overlay (panels/Ask.qml). Living
// here as a singleton -- not inside the Ask popup itself -- is what lets a
// question keep going after the popup is closed: shell.qml destroys the Ask
// Item (and everything owned by it) the moment the overlay closes, so a
// Process living there would get killed mid-answer. A singleton is never
// destroyed, so `proc` below survives closes, reopens and conversation
// switches; Ask.qml just displays whatever state is here.
//
// Each conversation is a real `pi` session (its own --session-id) plus our
// own transcript file on disk, both keyed by that id -- see sessionPath().
// pi's own session memory is what lets a later question in the same
// conversation pick up where it left off; our own files just mirror that on
// screen and let us list/reload past conversations pi has no notion of.
Singleton {
    id: root

    readonly property string sessionsDir: Quickshell.env("HOME") + "/.local/state/quickshell-ask/sessions"
    readonly property string indexPath: root.sessionsDir + "/index.jsonl"
    readonly property string dotfilesDir: Quickshell.env("HOME") + "/dotfiles"
    function sessionPath(id) { return root.sessionsDir + "/" + id + ".jsonl"; }
    function newId() { return "qsask-" + Date.now() + "-" + Math.floor(Math.random() * 1000); }

    // Past conversations, most-recent-first: [{id, createdAt}, ...]. Loaded
    // once (below) and appended to as conversations get registered.
    property var sessionList: []
    // -1 = the current, brand-new, not-yet-registered conversation. 0..N-1
    // indexes into sessionList for a past one.
    property int currentIndex: -1
    property string currentSessionId: root.newId()

    // Whatever conversation is on screen right now.
    property var messages: []
    property string error: ""
    property bool running: false
    // Text of the answer currently streaming in, shown live below the
    // committed messages and folded into `messages` once the process exits.
    // Only updated here when it belongs to the conversation on screen right
    // now -- see _askCtx below.
    property string partialAnswer: ""

    // Bookkeeping for whichever `ask()` call is in flight, kept separate from
    // the on-screen state above so switching conversations (or closing and
    // reopening the popup) mid-answer can't splice one conversation's reply
    // into another's transcript. Whatever conversation the answer belongs to
    // still gets it in its history file; it only also updates
    // messages/partialAnswer if it's still the one on screen when the answer
    // arrives.
    property var _askCtx: null

    function parseLines(text) {
        const out = [];
        for (const line of text.split("\n")) {
            if (line.trim() === "") continue;
            try {
                out.push(JSON.parse(line));
            } catch (e) {
                // skip a malformed line rather than lose the rest
            }
        }
        return out;
    }

    Component.onCompleted: {
        indexLoader.command = ["sh", "-c", 'test -f "$1" && cat "$1"', "load", root.indexPath];
        indexLoader.running = true;
    }

    Process {
        id: indexLoader
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const loaded = root.parseLines(text);
                loaded.reverse(); // file is append-only oldest-first; show newest-first
                root.sessionList = loaded;
            }
        }
    }

    // Called when the overlay is freshly opened (SUPER+I) -- always starts a
    // blank conversation, never resumes wherever it was left last time.
    function startNewConversation(): void {
        root.currentIndex = -1;
        root.currentSessionId = root.newId();
        root.messages = [];
        root.error = "";
        root.partialAnswer = "";
    }

    function registerCurrent(): void {
        if (root.currentIndex !== -1) return; // already a real, past conversation
        const rec = {id: root.currentSessionId, createdAt: new Date().toISOString()};
        root.sessionList = [rec].concat(root.sessionList);
        root.currentIndex = 0;
        indexWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" >> "$2"',
            "append", JSON.stringify(rec), root.indexPath];
        indexWriter.running = true;
    }

    Process { id: indexWriter }

    function appendHistory(sessionId: string, role: string, text: string): void {
        historyWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" >> "$2"',
            "append", JSON.stringify({role: role, text: text}), root.sessionPath(sessionId)];
        historyWriter.running = true;
    }

    Process { id: historyWriter }

    // Switches the conversation shown/typed-into, clamped to
    // [-1, sessionList.length - 1]. -1 always means "start a fresh one".
    function switchTo(index: int): void {
        const clamped = Math.max(-1, Math.min(index, root.sessionList.length - 1));
        if (clamped === root.currentIndex) return;
        root.currentIndex = clamped;
        root.error = "";
        root.partialAnswer = "";
        if (clamped === -1) {
            root.currentSessionId = root.newId();
            root.messages = [];
        } else {
            root.currentSessionId = root.sessionList[clamped].id;
            sessionLoader.command = ["sh", "-c", 'test -f "$1" && cat "$1"',
                "load", root.sessionPath(root.currentSessionId)];
            sessionLoader.running = true;
        }
    }

    Process {
        id: sessionLoader
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.messages = root.parseLines(text)
        }
    }

    function ask(question: string): void {
        if (question.trim() === "" || root.running) return;
        root.registerCurrent();
        const sid = root.currentSessionId;
        root.messages = root.messages.concat([{role: "you", text: question}]);
        root.appendHistory(sid, "you", question);
        root.error = "";
        root.partialAnswer = "";
        root.running = true;
        root._askCtx = {sid: sid, buffer: ""};
        // Run through sh -c with $1/$2 for the question/session id (never
        // interpolated into the script string) and stdin redirected from
        // /dev/null -- qs's own stdin isn't a closed/empty pipe, so without
        // this pi -p sits for a few seconds waiting for piped input before
        // answering. --mode json streams one JSON event per line as the
        // answer is generated (rather than printing the whole answer only
        // once it's done), which is what lets the transcript fill in live.
        proc.command = ["sh", "-c",
            'exec pi --session-id "$2" --tools read,grep,find,ls --mode json -p "$1" < /dev/null',
            "ask", question, sid];
        proc.workingDirectory = root.dotfilesDir;
        proc.running = true;
    }

    Process {
        id: proc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim() === "") return;
                let event;
                try {
                    event = JSON.parse(line);
                } catch (e) {
                    return; // stray non-JSON output -- ignore rather than crash the parser
                }
                const ame = event.assistantMessageEvent;
                if (event.type !== "message_update" || !ame || ame.type !== "text_delta") return;
                const ctx = root._askCtx;
                ctx.buffer += ame.delta;
                if (ctx.sid === root.currentSessionId) root.partialAnswer = ctx.buffer;
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                // pi prints this once, the very first time a --session-id is
                // used, to stderr -- harmless, not worth surfacing as an error.
                const t = text.trim();
                const ctx = root._askCtx;
                if (t !== "" && t.indexOf("No project session found") < 0 && ctx.sid === root.currentSessionId)
                    root.error = t;
            }
        }
        onExited: exitCode => {
            root.running = false;
            const ctx = root._askCtx;
            const onScreen = ctx.sid === root.currentSessionId;
            if (ctx.buffer !== "") {
                root.appendHistory(ctx.sid, "ai", ctx.buffer);
                if (onScreen) {
                    root.messages = root.messages.concat([{role: "ai", text: ctx.buffer}]);
                    root.partialAnswer = "";
                }
            }
            if (exitCode !== 0 && onScreen && root.error === "")
                root.error = "pi exited with code " + exitCode;
        }
    }

    function openInTerminal(sessionId: string): void {
        termProc.command = ["kitty", "-e", "sh", "-c",
            'exec pi --session-id "$1" --tools read,grep,find,ls', "term", sessionId];
        termProc.running = true;
    }

    Process {
        id: termProc
        workingDirectory: root.dotfilesDir
    }
}
